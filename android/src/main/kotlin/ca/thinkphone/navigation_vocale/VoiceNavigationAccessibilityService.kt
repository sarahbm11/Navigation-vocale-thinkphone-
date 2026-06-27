package ca.thinkphone.navigation_vocale

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Intent
import android.graphics.Path
import android.graphics.Rect
import android.os.Build
import android.util.DisplayMetrics
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import androidx.annotation.RequiresApi

/**
 * Service d'accessibilité Android pour la navigation vocale.
 * Aucune donnée saisie ou affichée n'est enregistrée.
 */
class VoiceNavigationAccessibilityService : AccessibilityService() {

    companion object {
        var instance: VoiceNavigationAccessibilityService? = null
    }

    override fun onServiceConnected() {
        instance = this
    }

    override fun onUnbind(intent: Intent?): Boolean {
        instance = null
        return super.onUnbind(intent)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) { /* non utilisé */ }
    override fun onInterrupt() {}

    // --- Actions système ---

    fun performHome(): Boolean =
        performGlobalAction(GLOBAL_ACTION_HOME)

    fun performBack(): Boolean =
        performGlobalAction(GLOBAL_ACTION_BACK)

    fun performRecents(): Boolean =
        performGlobalAction(GLOBAL_ACTION_RECENTS)

    fun openNotifications(): Boolean =
        performGlobalAction(GLOBAL_ACTION_NOTIFICATIONS)

    fun closeCurrentApp(): Boolean =
        performGlobalAction(GLOBAL_ACTION_HOME)

    // --- Gestes d'écran ---

    @RequiresApi(Build.VERSION_CODES.N)
    fun scrollDown(): Boolean = dispatchSwipe(downward = true)

    @RequiresApi(Build.VERSION_CODES.N)
    fun scrollUp(): Boolean = dispatchSwipe(downward = false)

    @RequiresApi(Build.VERSION_CODES.N)
    fun swipeLeft(): Boolean = dispatchHorizontalSwipe(toLeft = true)

    @RequiresApi(Build.VERSION_CODES.N)
    fun swipeRight(): Boolean = dispatchHorizontalSwipe(toLeft = false)

    @RequiresApi(Build.VERSION_CODES.N)
    fun tap(targetDescription: String?): Boolean {
        if (targetDescription != null) {
            val node = findNodeByText(rootInActiveWindow, targetDescription)
            if (node != null) {
                return node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            }
        }
        return dispatchTap(screenCenter())
    }

    @RequiresApi(Build.VERSION_CODES.N)
    fun longPress(targetDescription: String?): Boolean {
        if (targetDescription != null) {
            val node = findNodeByText(rootInActiveWindow, targetDescription)
            if (node != null) {
                return node.performAction(AccessibilityNodeInfo.ACTION_LONG_CLICK)
            }
        }
        val center = screenCenter()
        return dispatchTap(center, durationMs = 800)
    }

    // --- Utilitaires privés ---

    @RequiresApi(Build.VERSION_CODES.N)
    private fun dispatchSwipe(downward: Boolean): Boolean {
        val (w, h) = screenSize()
        val cx = w / 2f
        val startY = if (downward) h * 0.3f else h * 0.7f
        val endY   = if (downward) h * 0.7f else h * 0.3f

        val path = Path().apply {
            moveTo(cx, startY)
            lineTo(cx, endY)
        }
        return dispatchGesture(GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 400))
            .build(), null, null)
    }

    @RequiresApi(Build.VERSION_CODES.N)
    private fun dispatchHorizontalSwipe(toLeft: Boolean): Boolean {
        val (w, h) = screenSize()
        val cy = h / 2f
        val startX = if (toLeft) w * 0.75f else w * 0.25f
        val endX   = if (toLeft) w * 0.25f else w * 0.75f

        val path = Path().apply {
            moveTo(startX, cy)
            lineTo(endX, cy)
        }
        return dispatchGesture(GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 300))
            .build(), null, null)
    }

    @RequiresApi(Build.VERSION_CODES.N)
    private fun dispatchTap(point: Pair<Float, Float>, durationMs: Long = 50): Boolean {
        val path = Path().apply { moveTo(point.first, point.second) }
        return dispatchGesture(GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, durationMs))
            .build(), null, null)
    }

    private fun screenSize(): Pair<Float, Float> {
        val wm = getSystemService(WINDOW_SERVICE) as WindowManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bounds = wm.currentWindowMetrics.bounds
            Pair(bounds.width().toFloat(), bounds.height().toFloat())
        } else {
            val metrics = DisplayMetrics()
            @Suppress("DEPRECATION")
            wm.defaultDisplay.getRealMetrics(metrics)
            Pair(metrics.widthPixels.toFloat(), metrics.heightPixels.toFloat())
        }
    }

    private fun screenCenter(): Pair<Float, Float> {
        val (w, h) = screenSize()
        return Pair(w / 2f, h / 2f)
    }

    private fun findNodeByText(root: AccessibilityNodeInfo?, text: String): AccessibilityNodeInfo? {
        if (root == null) return null
        val lower = text.lowercase()

        if (root.text?.toString()?.lowercase()?.contains(lower) == true ||
            root.contentDescription?.toString()?.lowercase()?.contains(lower) == true) {
            return root
        }
        for (i in 0 until root.childCount) {
            val found = findNodeByText(root.getChild(i), text)
            if (found != null) return found
        }
        return null
    }

    fun openAppByName(name: String): Boolean {
        val pm = packageManager
        val apps = pm.getInstalledApplications(0)
        val lower = name.lowercase()
        val app = apps.firstOrNull {
            pm.getApplicationLabel(it).toString().lowercase().contains(lower)
        } ?: return false

        val intent = pm.getLaunchIntentForPackage(app.packageName) ?: return false
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
        return true
    }
}
