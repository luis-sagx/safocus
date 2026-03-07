package com.example.safocus

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.net.VpnService
import android.os.Build
import android.os.Bundle
import android.os.Process
import android.provider.Settings
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterActivity() {

    companion object {
        const val EXTRA_EMERGENCY_EXT_PKG = "emergency_ext_pkg"
    }

    private val VPN_REQUEST_CODE = 1001
    private var blockControlChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── VPN Channel ──────────────────────────────────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.safocus/vpn"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startVpn" -> {
                    @Suppress("UNCHECKED_CAST")
                    val domains = call.argument<List<String>>("domains") ?: emptyList()
                    val intent = VpnService.prepare(this)
                    if (intent != null) {
                        SaFocusVpnService.pendingDomains = domains
                        startActivityForResult(intent, VPN_REQUEST_CODE)
                        result.success(true)
                    } else {
                        SaFocusVpnService.pendingDomains = domains
                        startVpnService(domains)
                        result.success(true)
                    }
                }
                "stopVpn" -> {
                    val stopIntent = Intent(this, SaFocusVpnService::class.java).apply {
                        action = SaFocusVpnService.ACTION_STOP
                    }
                    startService(stopIntent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // ── Apps Channel ─────────────────────────────────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.safocus/apps"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledApps" -> result.success(getInstalledUserApps())
                else -> result.notImplemented()
            }
        }

        // ── Blocked Attempts Channel ─────────────────────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.safocus/blocked_attempt"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAndClearAttempts" -> {
                    val attempts = SaFocusVpnService.getAndClearBlockedAttempts()
                    val list = attempts.map { (ts, domain) ->
                        mapOf("timestamp" to ts, "domain" to domain)
                    }
                    result.success(list)
                }
                else -> result.notImplemented()
            }
        }

        // ── Block Control Channel ─────────────────────────────────────────
        blockControlChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.safocus/block_control"
        ).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {

                    // ── Service lifecycle ─────────────────────────────────
                    "startUsageMonitor" -> {
                        val i = Intent(this, UsageMonitorService::class.java).apply {
                            action = UsageMonitorService.ACTION_START
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(i)
                        } else {
                            startService(i)
                        }
                        result.success(null)
                    }
                    "stopUsageMonitor" -> {
                        val i = Intent(this, UsageMonitorService::class.java).apply {
                            action = UsageMonitorService.ACTION_STOP
                        }
                        startService(i)
                        result.success(null)
                    }

                    // ── Populate exceeded-apps list ───────────────────────
                    "syncExceededApps" -> {
                        @Suppress("UNCHECKED_CAST")
                        val apps = call.argument<List<Map<String, Any>>>("apps") ?: emptyList()
                        val prefs = getSharedPreferences(
                            FocusBlockService.PREFS_BLOCK, MODE_PRIVATE
                        )
                        val exceeded = apps.map { it["packageName"] as String }.toSet()
                        val edit = prefs.edit().putStringSet(
                            FocusBlockService.KEY_EXCEEDED, exceeded
                        )
                        for (app in apps) {
                            val pkg = app["packageName"] as String
                            edit.putString("appname_$pkg",  app["appName"]     as? String ?: pkg)
                            edit.putInt("usedmins_$pkg",   (app["usedMinutes"] as? Int)  ?: 0)
                            edit.putInt("limitmins_$pkg",  (app["limitMinutes"] as? Int) ?: 0)
                        }
                        // Clear extension flags for apps no longer exceeded.
                        prefs.all.keys
                            .filter  { it.startsWith("ext_used_") }
                            .map     { it.removePrefix("ext_used_") }
                            .filter  { it !in exceeded }
                            .forEach { edit.remove("ext_used_$it") }
                        edit.apply()
                        result.success(null)
                    }

                    // ── Sync ALL limited apps so UsageMonitorService can
                    //    compute real-time usage without waiting for Flutter (Bug 4)
                    "syncAllLimitedApps" -> {
                        @Suppress("UNCHECKED_CAST")
                        val apps = call.argument<List<Map<String, Any>>>("apps") ?: emptyList()
                        val prefs = getSharedPreferences(
                            FocusBlockService.PREFS_BLOCK, MODE_PRIVATE
                        )
                        val limited = apps.map { it["packageName"] as String }.toSet()
                        val edit = prefs.edit()
                            .putStringSet(UsageMonitorService.KEY_ALL_LIMITED, limited)
                        for (app in apps) {
                            val pkg = app["packageName"] as String
                            edit.putString("appname_$pkg", app["appName"] as? String ?: pkg)
                            edit.putInt("limitmins_$pkg", (app["limitMinutes"] as? Int) ?: 0)
                        }
                        edit.apply()
                        result.success(null)
                    }

                    // ── Notification permission (Bug 2: Android 13+) ─────────
                    "hasNotificationPermission" -> {
                        val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
                                PackageManager.PERMISSION_GRANTED
                        } else true
                        result.success(granted)
                    }
                    "requestNotificationPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                                1002
                            )
                        }
                        result.success(null)
                    }

                    // ── Reset extension flags at midnight ─────────────────
                    "resetExtUsed" -> {
                        val prefs = getSharedPreferences(
                            FocusBlockService.PREFS_BLOCK, MODE_PRIVATE
                        )
                        val edit = prefs.edit()
                        prefs.all.keys
                            .filter { it.startsWith("ext_used_") }
                            .forEach { edit.remove(it) }
                        edit.apply()
                        result.success(null)
                    }

                    // ── Schedule midnight reset alarm ─────────────────────
                    "scheduleResetAlarm" -> {
                        ResetAlarmReceiver.scheduleNextMidnight(this)
                        result.success(null)
                    }

                    // ── Permissions ───────────────────────────────────────
                    "hasUsagePermission" -> {
                        result.success(hasUsageStatsPermission())
                    }
                    "openUsageSettings" -> {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(null)
                    }
                    "hasOverlayPermission" -> {
                        result.success(
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                                Settings.canDrawOverlays(this)
                            else true
                        )
                    }
                    "openOverlaySettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    Uri.parse("package:$packageName")
                                )
                            )
                        }
                        result.success(null)
                    }

                    // Legacy — kept so old onboarding screens don't crash.
                    "openAccessibilitySettings" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
        }

        // ── Usage Stats Channel ──────────────────────────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.safocus/usage"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getTodayUsage" -> {
                    if (!hasUsageStatsPermission()) {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.error("PERMISSION_DENIED", "Usage stats permission required", null)
                    } else {
                        result.success(getTodayUsageStats())
                    }
                }
                "hasUsagePermission" -> result.success(hasUsageStatsPermission())
                else -> result.notImplemented()
            }
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private fun getInstalledUserApps(): List<Map<String, String>> {
        val pm = packageManager
        val intent = Intent(Intent.ACTION_MAIN).apply { addCategory(Intent.CATEGORY_LAUNCHER) }
        val activities = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.queryIntentActivities(intent, android.content.pm.PackageManager.ResolveInfoFlags.of(0L))
        } else {
            @Suppress("DEPRECATION")
            pm.queryIntentActivities(intent, 0)
        }
        return activities
            .filter { it.activityInfo.packageName != packageName }
            .mapNotNull { ri ->
                try {
                    mapOf("name" to ri.loadLabel(pm).toString(), "package" to ri.activityInfo.packageName)
                } catch (_: Exception) { null }
            }
            .sortedBy { it["name"]!!.lowercase() }
    }

    private fun startVpnService(domains: List<String>) {
        val i = Intent(this, SaFocusVpnService::class.java).apply {
            action = SaFocusVpnService.ACTION_START
            putStringArrayListExtra(SaFocusVpnService.EXTRA_DOMAINS, ArrayList(domains))
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(i)
        else startService(i)
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun getTodayUsageStats(): Map<String, Int> {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0);      set(Calendar.MILLISECOND, 0)
        }
        return usm.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY, cal.timeInMillis, System.currentTimeMillis()
        )
            .filter { it.totalTimeInForeground > 0 }
            .associate { it.packageName to (it.totalTimeInForeground / 60_000).toInt() }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val extPkg = intent.getStringExtra(EXTRA_EMERGENCY_EXT_PKG)
        if (extPkg != null) {
            blockControlChannel?.invokeMethod("emergencyExtRequest", extPkg)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == VPN_REQUEST_CODE && resultCode == RESULT_OK) {
            startVpnService(SaFocusVpnService.pendingDomains)
        }
        super.onActivityResult(requestCode, resultCode, data)
    }
}
