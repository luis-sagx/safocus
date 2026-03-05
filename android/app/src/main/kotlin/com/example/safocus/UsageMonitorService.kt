package com.example.safocus

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.app.usage.UsageStatsManager

/**
 * Persistent ForegroundService that polls UsageStatsManager every 500 ms to
 * detect when an app with an exhausted daily limit comes to the foreground and
 * immediately launches BlockOverlayActivity.
 *
 * The list of exceeded packages (plus per-app metadata) is kept in the
 * "safocus_block" SharedPreferences, written by MainActivity through the
 * block_control MethodChannel whenever Flutter refreshes usage stats.
 */
class UsageMonitorService : Service() {

    companion object {
        const val ACTION_START = "com.example.safocus.START_MONITOR"
        const val ACTION_STOP  = "com.example.safocus.STOP_MONITOR"

        private const val NOTIF_CHANNEL_ID = "safocus_protection"
        private const val NOTIF_ID         = 9901
        private const val POLL_INTERVAL_MS = 500L

        // Packages that must never be blocked regardless of limits.
        private val IGNORED = setOf(
            "com.example.safocus",
            "com.android.systemui",
            "com.android.launcher",
            "com.android.launcher2",
            "com.android.launcher3",
            "com.google.android.apps.nexuslauncher",
            "com.sec.android.app.launcher",
            "com.miui.home",
            "com.huawei.android.launcher",
            "com.oppo.launcher",
            "com.oneplus.launcher",
            "com.realme.launcher",
        )
    }

    private val handler = Handler(Looper.getMainLooper())
    private var lastBlockedPkg: String = ""
    private var lastBlockTime: Long = 0L
    private val debounceMs = 3_000L

    // ── Runnable that polls every 500 ms ─────────────────────────────────────

    private val pollRunnable = object : Runnable {
        override fun run() {
            checkForegroundApp()
            handler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    // ── Service lifecycle ───────────────────────────────────────────────────

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopSelf()
                return START_NOT_STICKY
            }
        }

        try {
            startForegroundWithNotification()
        } catch (e: Exception) {
            // OS denied startForeground (background-start restriction or missing permission).
            // Stop cleanly — the next app-open will restart us via the channel.
            stopSelf()
            return START_NOT_STICKY
        }
        handler.post(pollRunnable)
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(pollRunnable)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ── Core detection logic ────────────────────────────────────────────────

    private fun checkForegroundApp() {
        val usm = getSystemService(USAGE_STATS_SERVICE) as? UsageStatsManager ?: return

        val now = System.currentTimeMillis()
        val currentPkg = usm.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            now - 1_000L,
            now
        ).maxByOrNull { it.lastTimeUsed }?.packageName ?: return

        if (currentPkg in IGNORED) return

        val prefs = getSharedPreferences(BlockOverlayActivity.PREFS_BLOCK, MODE_PRIVATE)
        val exceeded = prefs.getStringSet(KEY_EXCEEDED, emptySet()) ?: emptySet()
        if (currentPkg !in exceeded) return

        // Debounce: don't spam the overlay.
        if (currentPkg == lastBlockedPkg && now - lastBlockTime < debounceMs) return
        lastBlockedPkg = currentPkg
        lastBlockTime  = now

        val appName  = prefs.getString("appname_$currentPkg", currentPkg) ?: currentPkg
        val usedMins = prefs.getInt("usedmins_$currentPkg", 0)
        val limitMins = prefs.getInt("limitmins_$currentPkg", 0)

        val blockIntent = Intent(this, BlockOverlayActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
            putExtra(BlockOverlayActivity.EXTRA_PKG,       currentPkg)
            putExtra(BlockOverlayActivity.EXTRA_APP_NAME,  appName)
            putExtra(BlockOverlayActivity.EXTRA_USED_MINS, usedMins)
            putExtra(BlockOverlayActivity.EXTRA_LIMIT_MINS, limitMins)
        }
        startActivity(blockIntent)
    }

    // ── Notification ────────────────────────────────────────────────────────

    private fun startForegroundWithNotification() {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIF_CHANNEL_ID,
                "SaFocus",
                NotificationManager.IMPORTANCE_MIN          // silent, no heads-up
            ).apply {
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_SECRET
            }
            nm.createNotificationChannel(channel)
        }

        val notif = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NOTIF_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }.apply {
            setSmallIcon(R.mipmap.ic_launcher)
            setContentTitle("SaFocus")
            setContentText("Protección activa")
            setOngoing(true)
            setCategory(Notification.CATEGORY_SERVICE)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
            }
        }.build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIF_ID, notif, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIF_ID, notif)
        }
    }

    // Key shared with MainActivity for the exceeded-packages set.
    private val KEY_EXCEEDED = "exceeded_packages"
}
