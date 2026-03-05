package com.example.safocus

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Fires on device boot (and quick-boot on some OEMs).
 *
 *  1. Restarts UsageMonitorService so app-limit blocking is active immediately.
 *  2. Restarts the VPN/web-blocking service if it was previously enabled.
 *  3. Re-schedules the midnight reset alarm (it doesn't survive reboots).
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != "android.intent.action.QUICKBOOT_POWERON"
        ) return

        val flutterPrefs = context.getSharedPreferences(
            "FlutterSharedPreferences", Context.MODE_PRIVATE
        )

        // ── 1. Start UsageMonitorService ─────────────────────────────────
        val monitorIntent = Intent(context, UsageMonitorService::class.java).apply {
            this.action = UsageMonitorService.ACTION_START
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(monitorIntent)
        } else {
            context.startService(monitorIntent)
        }

        // ── 2. Restart VPN if it was active ──────────────────────────────
        val vpnEnabled = flutterPrefs.getBoolean("flutter.vpn_enabled", false)
        if (vpnEnabled) {
            val vpnIntent = Intent(context, SaFocusVpnService::class.java).apply {
                this.action = SaFocusVpnService.ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(vpnIntent)
            } else {
                context.startService(vpnIntent)
            }
        }

        // ── 3. Re-schedule midnight reset alarm ──────────────────────────
        ResetAlarmReceiver.scheduleNextMidnight(context)
    }
}
