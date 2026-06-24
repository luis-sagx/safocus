package com.example.safocus

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Full-screen blocking overlay shown when the user opens an app that has
 * exceeded its daily time limit.
 *
 * This is a plain Android Activity — no Flutter engine overhead.
 * The "Emergency extension" button opens the SaFocus main app so the user
 * can request an extension from within the authenticated SaFocus UI.
 */
class BlockOverlayActivity : Activity() {

    companion object {
        const val EXTRA_PKG = "pkg"
        const val EXTRA_APP_NAME = "app_name"
        const val EXTRA_USED_MINS = "used_mins"
        const val EXTRA_LIMIT_MINS = "limit_mins"
        const val EXTRA_DOMAIN = "domain"        // set for blocked-website mode
        const val PREFS_BLOCK = "safocus_block"
        const val KEY_EXT_USED = "ext_used_"
        const val KEY_DISMISSED = "dismissed_"   // ts when user tapped "go home"

        /** Called by MainActivity after the Flutter side grants an extension,
         *  so we can mark the package as extended today in SharedPreferences. */
        fun markExtensionUsed(activity: Activity, pkg: String) {
            activity.getSharedPreferences(PREFS_BLOCK, MODE_PRIVATE)
                .edit()
                .putBoolean("$KEY_EXT_USED$pkg", true)
                .apply()
        }
    }

    private var blockedPkg = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Stay visible above lock screen and keep screen on.
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
        )

        // NOTE: Immersive mode is applied in onWindowFocusChanged — DecorView
        // is not yet created here (before setContentView), calling
        // window.insetsController at this point throws NPE on some devices.

        blockedPkg = intent.getStringExtra(EXTRA_PKG) ?: ""
        val appName = intent.getStringExtra(EXTRA_APP_NAME) ?: "App"
        val usedMins = intent.getIntExtra(EXTRA_USED_MINS, 0)
        val limitMins = intent.getIntExtra(EXTRA_LIMIT_MINS, 0)
        val domain = intent.getStringExtra(EXTRA_DOMAIN)
        val isWeb = !domain.isNullOrEmpty()

        val dp = resources.displayMetrics.density

        // ── Root container ─────────────────────────────────────────────
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#0D0D0D"))
            setPadding(
                (32 * dp).toInt(), (24 * dp).toInt(),
                (32 * dp).toInt(), (24 * dp).toInt()
            )
        }

        // Lock emoji
        root.addView(textView("\uD83D\uDD12", 52f, Color.WHITE, Gravity.CENTER))
        root.addView(space(20, dp))

        // Title — differs for app-limit vs website block.
        root.addView(
            textView(
                if (isWeb) "Sitio bloqueado" else "Límite alcanzado",
                24f, Color.WHITE, Gravity.CENTER, bold = true,
            )
        )
        root.addView(space(8, dp))

        // Subtitle — app name or domain.
        root.addView(
            textView(
                if (isWeb) domain!! else appName,
                18f, Color.parseColor("#A0A0A0"), Gravity.CENTER,
            )
        )
        root.addView(space(8, dp))

        // Detail line.
        root.addView(
            textView(
                if (isWeb)
                    "Este sitio está bloqueado por SaFocus"
                else
                    "Usaste $usedMins min de un límite de $limitMins min hoy",
                14f, Color.parseColor("#555555"), Gravity.CENTER,
            )
        )
        root.addView(space(40, dp))

        // ── "Volver al inicio" button ─────────────────────────────────
        val homeBtn = Button(this).apply {
            text = "Volver al inicio"
            setBackgroundColor(Color.parseColor("#7C3AED"))
            setTextColor(Color.WHITE)
            textSize = 16f
            typeface = Typeface.DEFAULT_BOLD
            setPadding(
                (24 * dp).toInt(), (14 * dp).toInt(),
                (24 * dp).toInt(), (14 * dp).toInt()
            )
        }
        homeBtn.setOnClickListener { goHome() }
        root.addView(homeBtn, fullWidthParams(dp))

        setContentView(root)
    }

    // ── Helpers ─────────────────────────────────────────────────────────────

    private fun textView(
        text: String,
        sizeSp: Float,
        color: Int,
        gravity: Int,
        bold: Boolean = false,
    ) = TextView(this).apply {
        this.text = text
        textSize = sizeSp
        setTextColor(color)
        this.gravity = gravity
        if (bold) typeface = Typeface.DEFAULT_BOLD
    }

    private fun space(dp8: Int, density: Float) = View(this).apply {
        layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            (dp8 * density).toInt()
        )
    }

    private fun fullWidthParams(density: Float) = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT,
        LinearLayout.LayoutParams.WRAP_CONTENT
    )

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) applyImmersiveMode()
    }

    /** Apply full-screen immersive mode. Called from onWindowFocusChanged so
     *  the DecorView is guaranteed to exist. */
    private fun applyImmersiveMode() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.let {
                it.hide(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
                it.systemBarsBehavior =
                    WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            )
        }
    }

    // ── Navigation ───────────────────────────────────────────────────────────

    private fun goHome() {
        // Record the dismissal so the monitor doesn't immediately re-launch the
        // block screen during the home transition (Bug 1 flicker fix).
        if (blockedPkg.isNotEmpty()) {
            getSharedPreferences(PREFS_BLOCK, MODE_PRIVATE)
                .edit()
                .putLong("$KEY_DISMISSED$blockedPkg", System.currentTimeMillis())
                .apply()
        }
        startActivity(
            Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
        )
        finishAndRemoveTask()
    }

    // ── Block back button ────────────────────────────────────────────────────

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        goHome()
    }
}
