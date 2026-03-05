package com.example.safocus

/**
 * Kept as a constants-only holder so existing call-sites in MainActivity
 * (e.g. FocusBlockService.PREFS_BLOCK) continue to compile without changes.
 *
 * The actual foreground detection logic has moved to UsageMonitorService,
 * which uses UsageStatsManager instead of AccessibilityService.
 */
object FocusBlockService {
    const val PREFS_BLOCK  = "safocus_block"
    const val KEY_EXCEEDED = "exceeded_packages"
}
