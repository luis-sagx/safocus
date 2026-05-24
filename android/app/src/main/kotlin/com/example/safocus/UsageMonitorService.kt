package com.example.safocus

import android.app.ActivityManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import java.util.Calendar
import java.util.TimeZone

/**
 * Persistent ForegroundService that polls UsageStatsManager every 500 ms to:
 *   1. Detect in real-time when an app exceeds its daily limit (Bug 4 fix).
 *   2. Show a countdown notification with remaining time (Bug 2 + Bug 3 fix).
 *   3. Detect PiP / floating-window usage of blocked apps and kill them (Bug 1 fix).
 *
 * App limits are stored in "safocus_block" SharedPreferences by MainActivity via
 * the block_control MethodChannel (syncAllLimitedApps + syncExceededApps).
 */
class UsageMonitorService : Service() {

    companion object {
        const val ACTION_START = "com.example.safocus.START_MONITOR"
        const val ACTION_STOP  = "com.example.safocus.STOP_MONITOR"

        // SharedPreferences key for ALL apps that have a limit set (not only exceeded).
        // Written by MainActivity#syncAllLimitedApps so this service can compute
        // real-time usage without waiting for Flutter to push an exceeded event.
        const val KEY_ALL_LIMITED = "all_limited_packages"

        private const val NOTIF_CHANNEL_PROTECTION = "safocus_protection"  // silent, foreground
        private const val NOTIF_CHANNEL_LIMITS      = "safocus_limits"      // high-priority, countdown

        private const val NOTIF_ID_SERVICE = 9901
        const val  NOTIF_ID_LIMIT   = 9902

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

    // Block-launch debounce state
    private var lastBlockedPkg  = ""
    private var lastBlockTime   = 0L
    private val debounceMs      = 3_000L

    // Limit-notification throttle state (Bug 3)
    private var limitNotifPkg        = ""
    private var lastNotifUpdateTime  = 0L

    // PiP / floating-window system overlay (covers PiP windows, Bug 1 fix)
    private var pipOverlayView: View? = null
    private var pipWm: WindowManager? = null
    private var pipPkg = ""

    // ── Poll runnable (every 500 ms) ─────────────────────────────────────────

    private val pollRunnable = object : Runnable {
        override fun run() {
            checkForegroundApp()
            checkPipAndFloatingWindows()   // Bug 1
            handler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    // ── Service lifecycle ────────────────────────────────────────────────────

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        try {
            startForegroundWithNotification()
        } catch (e: Exception) {
            stopSelf()
            return START_NOT_STICKY
        }
        handler.post(pollRunnable)
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(pollRunnable)
        cancelLimitNotification()
        removePipBlockOverlay()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ── Bug 4: Real-time foreground-app check ────────────────────────────────

    private fun checkForegroundApp() {
        val usm = getSystemService(USAGE_STATS_SERVICE) as? UsageStatsManager ?: return
        val now = System.currentTimeMillis()

        // Most-recently used package in the last second = current foreground app.
        val currentPkg = usm.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            now - 1_000L,
            now
        ).maxByOrNull { it.lastTimeUsed }?.packageName ?: run {
            if (limitNotifPkg.isNotEmpty()) cancelLimitNotification()
            return
        }

        if (currentPkg in IGNORED) {
            if (limitNotifPkg.isNotEmpty()) cancelLimitNotification()
            return
        }

        val prefs     = getSharedPreferences(BlockOverlayActivity.PREFS_BLOCK, MODE_PRIVATE)
        val appName   = prefs.getString("appname_$currentPkg", currentPkg) ?: currentPkg
        val limitMins = prefs.getInt("limitmins_$currentPkg", -1)

        if (limitMins > 0) {
            // Real-time usage via UsageStatsManager (Bug 4 core fix)
            val realUsedMs   = getRealTimeUsageMs(usm, currentPkg)
            val realUsedMins = (realUsedMs / 60_000).toInt()
            val remainingMs  = (limitMins * 60_000L) - realUsedMs

            if (remainingMs > 0) {
                // App still has time — show/update countdown notification (Bug 2+3)
                maybeUpdateLimitNotification(currentPkg, appName, remainingMs, limitMins)
            } else {
                // Limit reached in real-time — block immediately (Bug 4)
                cancelLimitNotification()

                // Persist the newly exceeded state so BlockOverlayActivity can read it.
                val exceeded = prefs.getStringSet(
                    FocusBlockService.KEY_EXCEEDED, emptySet()
                )?.toMutableSet() ?: mutableSetOf()
                if (currentPkg !in exceeded) {
                    exceeded.add(currentPkg)
                    prefs.edit()
                        .putStringSet(FocusBlockService.KEY_EXCEEDED, exceeded)
                        .putInt("usedmins_$currentPkg", realUsedMins)
                        .apply()
                }
                triggerBlock(currentPkg, appName, realUsedMins, limitMins, now)
            }
        } else {
            // No limit stored locally — fall back to the exceeded set pushed by Flutter.
            val exceeded = prefs.getStringSet(FocusBlockService.KEY_EXCEEDED, emptySet()) ?: emptySet()
            if (currentPkg in exceeded) {
                cancelLimitNotification()
                val usedMins  = prefs.getInt("usedmins_$currentPkg", 0)
                val lMins     = prefs.getInt("limitmins_$currentPkg", 0)
                triggerBlock(currentPkg, appName, usedMins, lMins, now)
            } else if (currentPkg != limitNotifPkg && limitNotifPkg.isNotEmpty()) {
                cancelLimitNotification()
            }
        }
    }

    /** Debounce-guarded launch of BlockOverlayActivity (Bug 4: FLAG_ACTIVITY_NEW_TASK). */
    private fun triggerBlock(pkg: String, appName: String, usedMins: Int, limitMins: Int, now: Long) {
        if (pkg == lastBlockedPkg && now - lastBlockTime < debounceMs) return
        lastBlockedPkg = pkg
        lastBlockTime  = now
        val i = Intent(this, BlockOverlayActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
            putExtra(BlockOverlayActivity.EXTRA_PKG,        pkg)
            putExtra(BlockOverlayActivity.EXTRA_APP_NAME,   appName)
            putExtra(BlockOverlayActivity.EXTRA_USED_MINS,  usedMins)
            putExtra(BlockOverlayActivity.EXTRA_LIMIT_MINS, limitMins)
        }
        startActivity(i)
    }

    // ── Bug 1: PiP / floating-window detection ───────────────────────────────

    /**
     * Reads UsageEvents for the last 3 seconds looking for ACTIVITY_RESUMED events
     * belonging to blocked apps.  This catches apps opened in PiP mode, bubble /
     * chat-head overlays, and any other mechanism that brings a blocked app to the
     * screen without making it the "top" foreground app according to queryUsageStats.
     *
     * When detected, the process is killed via killBackgroundProcesses (requires
     * KILL_BACKGROUND_PROCESSES permission declared in AndroidManifest.xml).
     */
    private fun checkPipAndFloatingWindows() {
        val usm = getSystemService(USAGE_STATS_SERVICE) as? UsageStatsManager ?: return
        val am  = getSystemService(ACTIVITY_SERVICE) as? ActivityManager ?: return
        val prefs = getSharedPreferences(BlockOverlayActivity.PREFS_BLOCK, MODE_PRIVATE)

        // Build the set of packages that are currently blocked.
        val exceeded    = prefs.getStringSet(FocusBlockService.KEY_EXCEEDED, emptySet()) ?: emptySet()
        val allLimited  = prefs.getStringSet(KEY_ALL_LIMITED, emptySet()) ?: emptySet()

        val blockedNow  = exceeded.toMutableSet()
        for (pkg in allLimited) {
            val lim = prefs.getInt("limitmins_$pkg", -1)
            if (lim <= 0) continue
            if ((getRealTimeUsageMs(usm, pkg) / 60_000) >= lim) blockedNow.add(pkg)
        }
        // If nothing blocked, dismiss any lingering PiP overlay.
        if (blockedNow.isEmpty()) {
            if (pipOverlayView != null) removePipBlockOverlay()
            return
        }

        // Query recent usage events and kill blocked apps found running.
        val now    = System.currentTimeMillis()
        val events = usm.queryEvents(now - 3_000L, now)
        val event  = UsageEvents.Event()
        val killed = mutableSetOf<String>()

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val pkg = event.packageName ?: continue
            if (pkg in IGNORED || pkg in killed) continue
            if (pkg !in blockedNow) continue
            if (event.eventType != UsageEvents.Event.ACTIVITY_RESUMED) continue

            try {
                am.killBackgroundProcesses(pkg)
                killed.add(pkg)
                // Show TYPE_APPLICATION_OVERLAY system window that sits above
                // PiP windows — normal Activities cannot cover them.
                val appName   = prefs.getString("appname_$pkg", pkg) ?: pkg
                val usedMins  = (getRealTimeUsageMs(usm, pkg) / 60_000).toInt()
                val limitMins = prefs.getInt("limitmins_$pkg", 0)
                showPipBlockOverlay(appName, pkg, usedMins, limitMins)
            } catch (_: SecurityException) { /* permission not granted — ignore */ }
        }

        // Additionally iterate appTasks (covers PiP tasks on API 29+).
        try {
            for (task in am.appTasks) {
                val taskPkg = task.taskInfo?.baseActivity?.packageName ?: continue
                if (taskPkg in IGNORED || taskPkg !in blockedNow) continue
                if (taskPkg in killed) continue
                try {
                    am.killBackgroundProcesses(taskPkg)
                    val appName   = prefs.getString("appname_$taskPkg", taskPkg) ?: taskPkg
                    val usedMins  = (getRealTimeUsageMs(usm, taskPkg) / 60_000).toInt()
                    val limitMins = prefs.getInt("limitmins_$taskPkg", 0)
                    showPipBlockOverlay(appName, taskPkg, usedMins, limitMins)
                } catch (_: SecurityException) {}
            }
        } catch (_: Exception) {}
    }

    // ── PiP / floating-window system overlay ────────────────────────────────

    /**
     * Shows a full-screen TYPE_APPLICATION_OVERLAY window that sits above PiP
     * windows and all regular activities. This is the only reliable way to block
     * an app running in picture-in-picture or floating-window mode.
     *
     * Requires SYSTEM_ALERT_WINDOW permission (declared in AndroidManifest.xml).
     * If the permission is not granted, falls back to launching BlockOverlayActivity.
     */
    @Suppress("DEPRECATION")
    private fun showPipBlockOverlay(
        appName: String,
        pkg: String,
        usedMins: Int,
        limitMins: Int,
    ) {
        // If already showing for the same package, do nothing.
        if (pkg == pipPkg && pipOverlayView != null) return

        // Check SYSTEM_ALERT_WINDOW permission at runtime (Android 6+).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !Settings.canDrawOverlays(this)
        ) {
            // No overlay permission — fall back to Activity-based block.
            triggerBlock(pkg, appName, usedMins, limitMins, System.currentTimeMillis())
            return
        }

        // Remove any overlay currently shown for a different package.
        removePipBlockOverlay()

        val dp = resources.displayMetrics.density

        // ── Root container ────────────────────────────────────────────────
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#0D0D0D"))
            setPadding(
                (32 * dp).toInt(), (24 * dp).toInt(),
                (32 * dp).toInt(), (24 * dp).toInt(),
            )
        }

        fun tv(text: String, sizeSp: Float, color: Int, bold: Boolean = false) =
            TextView(this).apply {
                this.text = text
                textSize = sizeSp
                setTextColor(color)
                gravity = Gravity.CENTER
                if (bold) typeface = Typeface.DEFAULT_BOLD
            }

        fun space(dpVal: Int) = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, (dpVal * dp).toInt()
            )
        }

        root.addView(tv("\uD83D\uDD12", 52f, Color.WHITE))
        root.addView(space(20))
        root.addView(tv("Límite alcanzado", 24f, Color.WHITE, bold = true))
        root.addView(space(8))
        root.addView(tv(appName, 18f, Color.parseColor("#A0A0A0")))
        root.addView(space(8))
        root.addView(
            tv(
                "Usaste $usedMins min de un límite de $limitMins min hoy",
                14f, Color.parseColor("#555555"),
            )
        )
        root.addView(space(40))

        val rowParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT,
        )

        // "Volver al inicio" button
        val homeBtn = Button(this).apply {
            text = "Volver al inicio"
            setBackgroundColor(Color.parseColor("#7C3AED"))
            setTextColor(Color.WHITE)
            textSize = 16f
            typeface = Typeface.DEFAULT_BOLD
            setPadding((24*dp).toInt(), (14*dp).toInt(), (24*dp).toInt(), (14*dp).toInt())
        }
        homeBtn.setOnClickListener {
            startActivity(Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            })
            removePipBlockOverlay()
        }
        root.addView(homeBtn, rowParams)

        // "Extensión de emergencia" button (once per day)
        val prefs = getSharedPreferences(BlockOverlayActivity.PREFS_BLOCK, MODE_PRIVATE)
        val extUsed = prefs.getBoolean("${BlockOverlayActivity.KEY_EXT_USED}$pkg", false)
        if (!extUsed) {
            root.addView(space(12))
            val extBtn = Button(this).apply {
                text = "Extensión de emergencia (+5 min)"
                setBackgroundColor(Color.parseColor("#1F2937"))
                setTextColor(Color.parseColor("#D1D5DB"))
                textSize = 14f
                setPadding((24*dp).toInt(), (12*dp).toInt(), (24*dp).toInt(), (12*dp).toInt())
            }
            extBtn.setOnClickListener {
                val intent = Intent(this@UsageMonitorService, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    putExtra(MainActivity.EXTRA_EMERGENCY_EXT_PKG, pkg)
                }
                startActivity(intent)
                removePipBlockOverlay()
            }
            root.addView(extBtn, rowParams)
        }

        // ── Add to WindowManager ──────────────────────────────────────────
        val wm = getSystemService(WINDOW_SERVICE) as? WindowManager ?: return
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_SYSTEM_ALERT,
            // No FLAG_NOT_TOUCH_MODAL so all touches are captured (no pass-through to PiP).
            // No FLAG_NOT_FOCUSABLE so buttons respond to clicks.
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            PixelFormat.OPAQUE,
        )

        try {
            wm.addView(root, params)
            pipOverlayView = root
            pipWm = wm
            pipPkg = pkg
        } catch (_: Exception) {
            // Window already added or other error — fall back to activity.
            triggerBlock(pkg, appName, usedMins, limitMins, System.currentTimeMillis())
        }
    }

    private fun removePipBlockOverlay() {
        pipOverlayView?.let {
            try { pipWm?.removeView(it) } catch (_: Exception) {}
        }
        pipOverlayView = null
        pipWm = null
        pipPkg = ""
    }

    // ── Bug 2 + 3: Limit countdown notification ──────────────────────────────

    /**
     * Shows or refreshes the limit countdown notification.
     * Throttled: updates every 60 s normally, every 30 s when < 2 min remaining,
     * or immediately when the tracked package changes.
     */
    private fun maybeUpdateLimitNotification(
        pkg: String,
        appName: String,
        remainingMs: Long,
        limitMins: Int,
    ) {
        val now = System.currentTimeMillis()
        val updateInterval = if (remainingMs < 120_000L) 30_000L else 60_000L

        // Always update when the app in focus changes.
        if (pkg != limitNotifPkg || now - lastNotifUpdateTime >= updateInterval) {
            if (pkg != limitNotifPkg) {
                cancelLimitNotification()   // clear previous app's notification
            }
            limitNotifPkg       = pkg
            lastNotifUpdateTime = now
            showLimitNotification(pkg, appName, remainingMs, limitMins)
        }
    }

    private fun showLimitNotification(
        pkg: String,
        appName: String,
        remainingMs: Long,
        limitMins: Int,
    ) {
        // Bug 2: runtime POST_NOTIFICATIONS check (Android 13+).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED
            ) return
        }

        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

        val remainingSecs = (remainingMs / 1_000).toInt()
        val usedMins      = (limitMins - remainingMs / 60_000).toInt().coerceAtLeast(0)

        // Bug 3: title changes when < 2 min remain.
        val title = if (remainingSecs <= 120) {
            "Últimos $remainingSecs segundos — $appName"
        } else {
            "Tiempo restante — $appName"
        }

        val pendingIntent = PendingIntent.getActivity(
            this, NOTIF_ID_LIMIT,
            Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra("open_screen", "limits")
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        // Bug 3: chronometer countdown + progress bar.
        val notif = NotificationCompat.Builder(this, NOTIF_CHANNEL_LIMITS)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText("$usedMins min usados de $limitMins min")
            .setUsesChronometer(true)
            .setChronometerCountDown(true)
            .setWhen(System.currentTimeMillis() + remainingMs)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setProgress(limitMins, usedMins, false)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()

        nm.notify(NOTIF_ID_LIMIT, notif)
    }

    private fun cancelLimitNotification() {
        limitNotifPkg       = ""
        lastNotifUpdateTime = 0L
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(NOTIF_ID_LIMIT)
    }

    // ── Notification channels + foreground notification ──────────────────────

    private fun startForegroundWithNotification() {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

        // Bug 2: Create BOTH channels at startup so they are always ready.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Silent protection-service channel.
            nm.createNotificationChannel(
                NotificationChannel(
                    NOTIF_CHANNEL_PROTECTION,
                    "SaFocus",
                    NotificationManager.IMPORTANCE_MIN
                ).apply {
                    setShowBadge(false)
                    lockscreenVisibility = Notification.VISIBILITY_SECRET
                }
            )
            // High-importance channel for limit countdowns (Bug 2 fix).
            nm.createNotificationChannel(
                NotificationChannel(
                    NOTIF_CHANNEL_LIMITS,
                    "Límites de uso",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    enableVibration(true)
                    setShowBadge(true)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                }
            )
        }

        val serviceNotif = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NOTIF_CHANNEL_PROTECTION)
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
            startForeground(NOTIF_ID_SERVICE, serviceNotif, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIF_ID_SERVICE, serviceNotif)
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    /**
     * Bug 4: Compute real-time foreground usage for [packageName] today, starting
     * from midnight in America/Guayaquil timezone, using UsageStatsManager.
     */
    private fun getRealTimeUsageMs(usm: UsageStatsManager, packageName: String): Long {
        val cal = Calendar.getInstance(TimeZone.getTimeZone("America/Guayaquil")).apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val stats = usm.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            cal.timeInMillis,
            System.currentTimeMillis()
        )
        return stats.find { it.packageName == packageName }?.totalTimeInForeground ?: 0L
    }
}
