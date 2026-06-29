package com.example.safocus

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import java.util.Calendar
import java.util.TimeZone

/**
 * Single source of truth for "how long was each app in the foreground today".
 *
 * Why this exists:
 *   `queryUsageStats(INTERVAL_DAILY, ...)` returns *multiple* overlapping buckets
 *   per package and the buckets are not aligned to midnight, so reading a single
 *   bucket's `totalTimeInForeground` (via `.find` or `.associate`) gives numbers
 *   that disagree between screens and inflate category totals (the 215-of-60
 *   false block). Instead we replay the raw foreground/background *events* since
 *   midnight and sum the actual visible intervals — the exact, dedup-by-design
 *   measurement. Both the Flutter display and the native blocker call this so the
 *   number a user sees and the number that triggers a block are always identical.
 *
 * A short TTL cache keeps a 2 Hz poll from re-scanning the day's events on every
 * call within a single check pass (the category loop asks per package).
 */
object UsageQuery {

    private const val CACHE_TTL_MS = 1_000L

    private var cacheAt = 0L
    private var cache: Map<String, Long> = emptyMap()

    /** Foreground milliseconds today for a single package. */
    fun foregroundMsTodayFor(usm: UsageStatsManager, pkg: String): Long =
        foregroundMsToday(usm)[pkg] ?: 0L

    /** Foreground minutes today for every package with any usage. */
    fun foregroundMinutesTodayAll(usm: UsageStatsManager): Map<String, Int> =
        foregroundMsToday(usm)
            .filterValues { it > 0L }
            .mapValues { (it.value / 60_000L).toInt() }

    @Synchronized
    fun foregroundMsToday(usm: UsageStatsManager): Map<String, Long> {
        val now = System.currentTimeMillis()
        if (cache.isNotEmpty() && now - cacheAt < CACHE_TTL_MS) return cache

        val begin = midnightGuayaquil()
        val totals = HashMap<String, Long>()
        val openSince = HashMap<String, Long>()

        val events = usm.queryEvents(begin, now)
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val pkg = event.packageName ?: continue
            when (event.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND ->
                    openSince[pkg] = event.timeStamp
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    // A session that opened before midnight has no FOREGROUND event
                    // inside the window — clamp its start to midnight.
                    val start = openSince.remove(pkg) ?: begin
                    if (event.timeStamp > start) {
                        totals[pkg] = (totals[pkg] ?: 0L) + (event.timeStamp - start)
                    }
                }
            }
        }
        // Apps still in the foreground at query time: count up to now.
        for ((pkg, start) in openSince) {
            if (now > start) totals[pkg] = (totals[pkg] ?: 0L) + (now - start)
        }

        cache = totals
        cacheAt = now
        return totals
    }

    private fun midnightGuayaquil(): Long =
        Calendar.getInstance(TimeZone.getTimeZone("America/Guayaquil")).apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
}
