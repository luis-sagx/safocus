package com.example.safocus

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar
import java.util.TimeZone

/**
 * BroadcastReceiver fired by AlarmManager every day at 00:00 America/Guayaquil.
 *
 * Responsibilities:
 *  1. Clear the "exceeded_packages" set in native SharedPreferences so the
 *     UsageMonitorService stops blocking apps for the new day.
 *  2. Remove all per-app extension and usage entries so they start fresh.
 *  3. Persist the reset date for the "check on app open" fallback mechanism.
 *  4. Re-schedule itself for the NEXT midnight (keeps the alarm alive forever).
 */
class ResetAlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        performReset(context)
        scheduleNextMidnight(context)
    }

    companion object {
        private const val REQUEST_CODE = 7788

        fun performReset(context: Context) {
            val prefs = context.getSharedPreferences(
                BlockOverlayActivity.PREFS_BLOCK, Context.MODE_PRIVATE
            )
            val today = todayInGuayaquil()
            prefs.edit()
                .remove("exceeded_packages")
                // Record the last native reset date so Flutter can check it.
                .putString("native_reset_date", today)
                .apply()

            // Also clear all per-app extension flags.
            val extKeys = prefs.all.keys.filter { it.startsWith("ext_used_") }
            val edit = prefs.edit()
            extKeys.forEach { edit.remove(it) }
            edit.apply()
        }

        /** Schedule (or re-schedule) the alarm to fire at next 00:00 Guayaquil. */
        fun scheduleNextMidnight(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            val calendar = Calendar.getInstance(TimeZone.getTimeZone("America/Guayaquil")).apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                add(Calendar.DAY_OF_YEAR, 1)   // always next midnight
            }

            val pendingIntent = buildPendingIntent(context)

            try {
                // On Android 12+ exact alarms need user grant via Special App Access.
                // Fall back to inexact if permission not yet granted.
                val canExact = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    alarmManager.canScheduleExactAlarms()
                } else {
                    true
                }

                if (canExact) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        calendar.timeInMillis,
                        pendingIntent
                    )
                } else {
                    // Inexact fallback — fires within a few minutes of midnight
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        calendar.timeInMillis,
                        pendingIntent
                    )
                }
            } catch (e: SecurityException) {
                // Permission denied at OS level — use inexact as last resort
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    calendar.timeInMillis,
                    pendingIntent
                )
            }
        }

        /** Cancel the scheduled alarm (e.g. when the user disables protection). */
        fun cancelAlarm(context: Context) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            am.cancel(buildPendingIntent(context))
        }

        private fun buildPendingIntent(context: Context): PendingIntent {
            val intent = Intent(context, ResetAlarmReceiver::class.java)
            return PendingIntent.getBroadcast(
                context,
                REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        fun todayInGuayaquil(): String {
            val cal = Calendar.getInstance(TimeZone.getTimeZone("America/Guayaquil"))
            return "%04d-%02d-%02d".format(
                cal.get(Calendar.YEAR),
                cal.get(Calendar.MONTH) + 1,
                cal.get(Calendar.DAY_OF_MONTH)
            )
        }
    }
}
