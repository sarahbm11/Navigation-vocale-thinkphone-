package ca.thinkphone.navigation_vocale

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat

class FloatingBubbleService : Service() {

    companion object {
        private const val CHANNEL_ID = "nav_vocale_bubble"
        private const val NOTIFICATION_ID = 5212
        var instance: FloatingBubbleService? = null

        fun updateMicActive(active: Boolean) {
            instance?.setActive(active)
        }
    }

    private lateinit var windowManager: WindowManager
    private var bubbleView: FrameLayout? = null
    private var layoutParams: WindowManager.LayoutParams? = null
    private var isMicActive = false

    override fun onCreate() {
        super.onCreate()
        instance = this
        createNotificationChannel()
        try {
            startForeground(NOTIFICATION_ID, buildNotification())
        } catch (e: Exception) {
            Log.e("NavVocale", "Bubble startForeground: ${e.message}")
        }
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createBubble()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        instance = null
        try { bubbleView?.let { windowManager.removeView(it) } } catch (_: Exception) {}
        super.onDestroy()
    }

    fun setActive(active: Boolean) {
        isMicActive = active
        bubbleView?.post {
            val color = if (active) Color.parseColor("#E8FF47") else Color.parseColor("#252730")
            bubbleView?.background = makeCircle(color)
            (bubbleView?.getChildAt(0) as? TextView)?.setTextColor(
                if (active) Color.BLACK else Color.parseColor("#E8FF47")
            )
        }
    }

    private fun createBubble() {
        val dp = resources.displayMetrics.density
        val size = (64 * dp).toInt()

        val label = TextView(this)
        label.text = "🎙"
        label.textSize = 22f
        label.gravity = android.view.Gravity.CENTER
        label.setTextColor(Color.parseColor("#E8FF47"))

        val frame = FrameLayout(this)
        frame.background = makeCircle(Color.parseColor("#252730"))
        frame.addView(label, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ))

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE

        val params = WindowManager.LayoutParams(
            size, size, type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply { gravity = Gravity.TOP or Gravity.START; x = 16; y = 300 }

        var dragging = false
        var startRawX = 0f; var startRawY = 0f
        var startPX = 0; var startPY = 0

        frame.setOnTouchListener { _, ev ->
            when (ev.action) {
                MotionEvent.ACTION_DOWN -> {
                    dragging = false
                    startRawX = ev.rawX; startRawY = ev.rawY
                    startPX = params.x; startPY = params.y; true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = ev.rawX - startRawX; val dy = ev.rawY - startRawY
                    if (kotlin.math.abs(dx) > 8 || kotlin.math.abs(dy) > 8) dragging = true
                    if (dragging) {
                        params.x = (startPX + dx).toInt(); params.y = (startPY + dy).toInt()
                        windowManager.updateViewLayout(frame, params)
                    }; true
                }
                MotionEvent.ACTION_UP -> {
                    if (!dragging) {
                        val intent = packageManager.getLaunchIntentForPackage(packageName)
                        intent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                        intent?.let { startActivity(it) }
                    }; true
                }
                else -> false
            }
        }

        layoutParams = params
        bubbleView = frame
        windowManager.addView(frame, params)
    }

    private fun makeCircle(color: Int) = GradientDrawable().apply {
        shape = GradientDrawable.OVAL
        setColor(color)
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
