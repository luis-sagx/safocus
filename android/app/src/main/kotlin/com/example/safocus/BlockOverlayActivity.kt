package com.example.safocus

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import kotlin.math.roundToInt

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

    // ── Cost-mirror (web-block) state ────────────────────────────────────────
    private val tollSeconds = 15
    private var secondsElapsed = 0
    private var mirrorHandler: Handler? = null
    private var mirrorRunnable: Runnable? = null
    private var counterView: TextView? = null
    private var continueBtn: Button? = null

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

        // ── Web block → "Espejo del costo" (separate UX from app-limit) ──
        if (isWeb) {
            setContentView(buildWebMirror(domain!!, dp))
            return
        }

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

    // ── Cost mirror (web block) ──────────────────────────────────────────────

    /**
     * "Espejo del costo": instead of a forgettable black "site blocked" page,
     * confront the user with what the distraction costs them — their chosen
     * identity, a live counter, the yearly scroll projection, and their streak.
     * "Continuar igual" is gated behind a 15s toll; "Volver" is always available.
     *
     * Reads personalised data from [PREFS_BLOCK] (written by the Flutter side via
     * the block_control channel). Missing data degrades gracefully.
     *
     * NOTE: copy is Spanish-only for now; full i18n is tracked as a follow-up.
     */
    private fun buildWebMirror(domain: String, dp: Float): View {
        val prefs = getSharedPreferences(PREFS_BLOCK, MODE_PRIVATE)
        val identity = prefs.getString("mirror_identity", null)
        val scrollHours = prefs.getInt("mirror_scroll_hours", 3).let {
            if (it <= 0) 3 else it
        }
        val streak = prefs.getInt("mirror_streak", 0)

        val accent = Color.parseColor("#7C3AED")

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#0D0D0D"))
            setPadding(
                (32 * dp).toInt(), (24 * dp).toInt(),
                (32 * dp).toInt(), (24 * dp).toInt()
            )
        }

        // Domain (muted)
        root.addView(textView(domain, 14f, Color.parseColor("#777777"), Gravity.CENTER))
        root.addView(space(8, dp))
        // Title
        root.addView(
            textView("Mirá lo que te cuesta", 26f, Color.WHITE, Gravity.CENTER, bold = true)
        )
        root.addView(space(20, dp))

        // Identity line (omitted if user skipped onboarding)
        identityLabel(identity)?.let {
            root.addView(
                textView("Esto te aleja de $it", 18f, accent, Gravity.CENTER, bold = true)
            )
            root.addView(space(16, dp))
        }

        // Live "time spent staring" counter — updated each second by the toll timer.
        val counter = textView(
            "Llevás 00:00 mirando esto", 16f, Color.parseColor("#E0E0E0"), Gravity.CENTER
        )
        counterView = counter
        root.addView(counter)
        root.addView(space(12, dp))

        // Yearly projection (ported from onboarding's _costMirrorBody)
        val hoursPerYear = scrollHours * 7 * 52
        val books = (hoursPerYear / 8.0).roundToInt()
        val episodes = (hoursPerYear / 0.75).roundToInt()
        val workouts = hoursPerYear
        root.addView(
            textView(
                "${hoursPerYear}h/año → $books libros · $episodes episodios · $workouts entrenos",
                14f, Color.parseColor("#A0A0A0"), Gravity.CENTER
            )
        )
        root.addView(space(16, dp))

        // Streak at stake (omitted for brand-new users)
        if (streak > 0) {
            root.addView(
                textView(
                    "🔥 $streak días en juego",
                    16f, Color.parseColor("#FF7A00"), Gravity.CENTER, bold = true
                )
            )
            root.addView(space(8, dp))
        }

        root.addView(space(32, dp))

        // "Volver" — always available, goes home.
        val backBtn = Button(this).apply {
            text = "Volver"
            setBackgroundColor(accent)
            setTextColor(Color.WHITE)
            textSize = 16f
            typeface = Typeface.DEFAULT_BOLD
            setPadding(
                (24 * dp).toInt(), (14 * dp).toInt(),
                (24 * dp).toInt(), (14 * dp).toInt()
            )
            setOnClickListener { goHome() }
        }
        root.addView(backBtn, fullWidthParams(dp))
        root.addView(space(12, dp))

        // "Continuar igual" — disabled behind the 15s toll countdown.
        val contBtn = Button(this).apply {
            text = "Continuar en ${tollSeconds}s"
            setBackgroundColor(Color.parseColor("#2A2A2A"))
            setTextColor(Color.parseColor("#CCCCCC"))
            textSize = 16f
            isEnabled = false
            alpha = 0.5f
            setPadding(
                (24 * dp).toInt(), (14 * dp).toInt(),
                (24 * dp).toInt(), (14 * dp).toInt()
            )
            setOnClickListener {
                sendTempAllow(domain)
                Toast.makeText(
                    this@BlockOverlayActivity,
                    "Volvé a la pestaña y recargá",
                    Toast.LENGTH_LONG
                ).show()
                finishAndRemoveTask()
            }
        }
        continueBtn = contBtn
        root.addView(contBtn, fullWidthParams(dp))

        startTollTimer()
        return root
    }

    private fun identityLabel(id: String?): String? = when (id) {
        "study"  -> "📚 Estudiar"
        "gym"    -> "💪 Gym"
        "create" -> "🎨 Crear"
        "sleep"  -> "😴 Dormir bien"
        else     -> null
    }

    /** Ticks once a second: advances the live counter and the toll countdown,
     *  enabling "Continuar igual" once the toll is paid. */
    private fun startTollTimer() {
        val handler = Handler(Looper.getMainLooper())
        mirrorHandler = handler
        val r = object : Runnable {
            override fun run() {
                secondsElapsed++
                counterView?.text = "Llevás ${formatMmSs(secondsElapsed)} mirando esto"
                val remaining = tollSeconds - secondsElapsed
                continueBtn?.let { btn ->
                    if (remaining > 0) {
                        btn.text = "Continuar en ${remaining}s"
                    } else {
                        btn.text = "Continuar igual"
                        btn.isEnabled = true
                        btn.alpha = 1f
                        btn.setBackgroundColor(Color.parseColor("#3A3A3A"))
                        btn.setTextColor(Color.WHITE)
                    }
                }
                handler.postDelayed(this, 1000)
            }
        }
        mirrorRunnable = r
        handler.postDelayed(r, 1000)
    }

    private fun formatMmSs(total: Int): String {
        val m = total / 60
        val s = total % 60
        return String.format("%02d:%02d", m, s)
    }

    /** Opens a 5-minute resolve window for [domain] in the VPN service. */
    private fun sendTempAllow(domain: String) {
        try {
            startService(
                Intent(this, SaFocusVpnService::class.java).apply {
                    action = SaFocusVpnService.ACTION_TEMP_ALLOW
                    putExtra(SaFocusVpnService.EXTRA_TEMP_ALLOW_DOMAIN, domain)
                }
            )
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        mirrorRunnable?.let { mirrorHandler?.removeCallbacks(it) }
        mirrorHandler = null
        mirrorRunnable = null
        super.onDestroy()
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
