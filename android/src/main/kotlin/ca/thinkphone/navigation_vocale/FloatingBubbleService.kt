package ca.thinkphone.navigation_vocale

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat

class FloatingBubbleService : Service() {

    companion object {
        private const val CHANNEL_ID = "nav_vocale_bubble"
        private const val NOTIFICATION_ID = 5212
        var instance: FloatingBubbleService? = null

        fun updateMicActive(active: Boolean) { instance?.setActive(active) }
        fun updateLastCmd(cmd: String)       { instance?.setLastCmd(cmd) }
    }

    private lateinit var windowManager: WindowManager
    private var rootFrame: FrameLayout? = null
    private var layoutParams: WindowManager.LayoutParams? = null

    private var isMicActive = false
    private var isExpanded  = false
    private var lastCommand = ""

    private var statusTv:    TextView? = null
    private var lastCmdTv:   TextView? = null
    private var micDotV:     View?     = null
    private var bubbleEmoji: TextView? = null

    private var dragging  = false
    private var startRawX = 0f; private var startRawY = 0f
    private var startPX   = 0;  private var startPY   = 0

    private val dp get() = resources.displayMetrics.density

    // ── Cycle de vie ──────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        instance = this
        createNotificationChannel()
        try { startForeground(NOTIFICATION_ID, buildNotification()) }
        catch (e: Exception) { Log.e("NavVocale", "Bubble startFg: ${e.message}") }
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createRoot()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        instance = null
        try { rootFrame?.let { windowManager.removeView(it) } } catch (_: Exception) {}
        super.onDestroy()
    }

    // ── API publique ───────────────────────────────────────────────────────────

    fun setActive(active: Boolean) {
        isMicActive = active
        rootFrame?.post {
            if (isExpanded) {
                micDotV?.background = dot(if (active) "#E8FF47" else "#444444")
                statusTv?.text = if (active) "En écoute…" else "Micro désactivé"
                statusTv?.setTextColor(Color.parseColor(if (active) "#A3A3A3" else "#555555"))
            } else {
                rootFrame?.background = circle(if (active) "#E8FF47" else "#252730")
                bubbleEmoji?.setTextColor(Color.parseColor(if (active) "#000000" else "#E8FF47"))
            }
        }
    }

    fun setLastCmd(cmd: String) {
        if (cmd.isNotEmpty()) lastCommand = cmd
        rootFrame?.post {
            lastCmdTv?.text = if (lastCommand.isEmpty()) "En attente…" else "→ $lastCommand"
        }
    }

    // ── Création ──────────────────────────────────────────────────────────────

    private fun createRoot() {
        val frame = FrameLayout(this)

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE

        val params = WindowManager.LayoutParams(
            px(64), px(64), type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply { gravity = Gravity.TOP or Gravity.START; x = 16; y = 300 }

        frame.setOnTouchListener { _, ev ->
            when (ev.action) {
                MotionEvent.ACTION_DOWN -> {
                    dragging = false
                    startRawX = ev.rawX; startRawY = ev.rawY
                    startPX = params.x;  startPY = params.y
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = ev.rawX - startRawX; val dy = ev.rawY - startRawY
                    if (kotlin.math.abs(dx) > 8 || kotlin.math.abs(dy) > 8) dragging = true
                    if (dragging) {
                        params.x = (startPX + dx).toInt(); params.y = (startPY + dy).toInt()
                        try { windowManager.updateViewLayout(frame, params) } catch (_: Exception) {}
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!dragging) toggle(frame, params)
                    true
                }
                else -> false
            }
        }

        layoutParams = params
        rootFrame = frame
        windowManager.addView(frame, params)
        buildMini(frame)
    }

    // ── Toggle mini ↔ panneau ─────────────────────────────────────────────────

    private fun toggle(frame: FrameLayout, params: WindowManager.LayoutParams) {
        isExpanded = !isExpanded
        frame.removeAllViews()
        if (isExpanded) {
            params.width  = px(252)
            params.height = WindowManager.LayoutParams.WRAP_CONTENT
            buildPanel(frame)
        } else {
            params.width  = px(64)
            params.height = px(64)
            buildMini(frame)
        }
        try { windowManager.updateViewLayout(frame, params) }
        catch (e: Exception) { Log.e("NavVocale", "updateLayout: ${e.message}") }
    }

    // ── Vue mini (bulle 64dp) ─────────────────────────────────────────────────

    private fun buildMini(frame: FrameLayout) {
        frame.background = circle(if (isMicActive) "#E8FF47" else "#252730")
        val emoji = TextView(this).apply {
            text = "🎙"; textSize = 22f; gravity = Gravity.CENTER
            setTextColor(Color.parseColor(if (isMicActive) "#000000" else "#E8FF47"))
        }
        bubbleEmoji = emoji
        frame.addView(emoji, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ))
    }

    // ── Vue panneau (mini fenêtre flottante) ──────────────────────────────────

    private fun buildPanel(frame: FrameLayout) {
        frame.background = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(Color.parseColor("#1A1B1F"))
            cornerRadius = 14 * dp
        }

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(px(12), px(10), px(12), px(12))
        }

        // Titre + indicateur mic
        val headerRow = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }

        val dotView = View(this).apply {
            background = dot(if (isMicActive) "#E8FF47" else "#444444")
        }
        micDotV = dotView
        headerRow.addView(dotView, LinearLayout.LayoutParams(px(10), px(10)).apply {
            gravity = Gravity.CENTER_VERTICAL; rightMargin = px(8)
        })

        val title = TextView(this).apply {
            text = "Navigation Vocale"; textSize = 12f
            setTextColor(Color.parseColor("#E8FF47"))
        }
        headerRow.addView(title, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
            gravity = Gravity.CENTER_VERTICAL
        })

        val tapHint = TextView(this).apply {
            text = "tap ×"; textSize = 10f
            setTextColor(Color.parseColor("#444444")); gravity = Gravity.CENTER_VERTICAL
        }
        headerRow.addView(tapHint, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT
        ))

        root.addView(headerRow, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
        ))

        // Séparateur
        root.addView(View(this).apply { setBackgroundColor(Color.parseColor("#2A2B30")) },
            LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 1).apply {
                topMargin = px(8); bottomMargin = px(8)
            })

        // Statut
        val stTv = TextView(this).apply {
            text = if (isMicActive) "En écoute…" else "Micro désactivé"; textSize = 11f
            setTextColor(Color.parseColor(if (isMicActive) "#A3A3A3" else "#555555"))
        }
        statusTv = stTv
        root.addView(stTv, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
        ))

        // Dernière commande
        val lcTv = TextView(this).apply {
            text = if (lastCommand.isEmpty()) "En attente…" else "→ $lastCommand"
            textSize = 12f; maxLines = 2; setTextColor(Color.WHITE)
        }
        lastCmdTv = lcTv
        root.addView(lcTv, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply { topMargin = px(4) })

        frame.addView(root, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT
        ))
    }

    // ── Helpers ────────────────────────────────────────────────────────────────

    private fun px(dp: Int) = (dp * this.dp).toInt()

    private fun circle(hex: String) = GradientDrawable().apply {
        shape = GradientDrawable.OVAL; setColor(Color.parseColor(hex))
    }
    private fun dot(hex: String) = GradientDrawable().apply {
        shape = GradientDrawable.OVAL; setColor(Color.parseColor(hex))
    }

    private fun buildNotification(): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Navigation Vocale")
            .setContentText("Bulle flottante active")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .build()

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Navigation Vocale Bulle", NotificationManager.IMPORTANCE_LOW)
            )
        }
    }
}
