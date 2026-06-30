package ca.thinkphone.navigation_vocale

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Intent
import android.graphics.Path
import android.os.Build
import android.os.Bundle
import android.util.DisplayMetrics
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import androidx.annotation.RequiresApi
import org.json.JSONArray
import org.json.JSONObject

/**
 * Service d'accessibilité Android — cœur de la navigation vocale.
 *
 * Capacités :
 *  - Navigation système (home, back, recents, notifications)
 *  - Gestes (scroll, swipe, tap, long press par coordonnées)
 *  - Tap ciblé par texte/description
 *  - Injection de texte dans n'importe quel champ
 *  - Lecture de l'arbre UI complet (pour résolution intelligente)
 *  - Lecture du texte visible à l'écran
 *  - Lecture des notifications
 *
 * Aucune donnée n'est enregistrée ou transmise par ce service.
 */
class VoiceNavigationAccessibilityService : AccessibilityService() {

    companion object {
        var instance: VoiceNavigationAccessibilityService? = null
    }

    override fun onServiceConnected() { instance = this }

    override fun onUnbind(intent: Intent?): Boolean {
        instance = null
        return super.onUnbind(intent)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}
    override fun onInterrupt() {}

    // -------------------------------------------------------------------------
    // Navigation système
    // -------------------------------------------------------------------------

    fun performHome()        = performGlobalAction(GLOBAL_ACTION_HOME)
    fun performBack()        = performGlobalAction(GLOBAL_ACTION_BACK)
    fun performRecents()     = performGlobalAction(GLOBAL_ACTION_RECENTS)
    fun openNotifications()  = performGlobalAction(GLOBAL_ACTION_NOTIFICATIONS)
    fun closeCurrentApp()    = performGlobalAction(GLOBAL_ACTION_HOME)

    fun openAppByName(name: String): Boolean {
        val pm = packageManager
        // Nettoie les articles français et normalise
        val query = name.lowercase()
            .removePrefix("l'").removePrefix("le ").removePrefix("la ")
            .removePrefix("les ").removePrefix("l'").trim()

        // Filtre : seulement les apps lançables (ont un intent de démarrage)
        val launchable = pm.getInstalledApplications(0).filter {
            pm.getLaunchIntentForPackage(it.packageName) != null
        }

        fun score(label: String): Int {
            val l = label.lowercase()
            return when {
                l == query                  -> 100  // correspondance exacte
                l.startsWith(query)         -> 80   // le label commence par la requête
                query.startsWith(l)         -> 70   // la requête commence par le label
                l.contains(query)           -> 50   // contient
                query.contains(l) && l.length >= 3 -> 30 // requête contient le label
                else                        -> 0
            }
        }

        val best = launchable
            .map { info -> Pair(info, score(pm.getApplicationLabel(info).toString())) }
            .filter { it.second > 0 }
            .maxByOrNull { it.second }
            ?.first ?: return false

        val intent = pm.getLaunchIntentForPackage(best.packageName) ?: return false
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
        return true
    }

    // -------------------------------------------------------------------------
    // Gestes d'écran
    // -------------------------------------------------------------------------

    @RequiresApi(Build.VERSION_CODES.N)
    fun scrollDown() = dispatchSwipe(downward = true)

    @RequiresApi(Build.VERSION_CODES.N)
    fun scrollUp() = dispatchSwipe(downward = false)

    @RequiresApi(Build.VERSION_CODES.N)
    fun swipeLeft() = dispatchHorizontalSwipe(toLeft = true)

    @RequiresApi(Build.VERSION_CODES.N)
    fun swipeRight() = dispatchHorizontalSwipe(toLeft = false)

    @RequiresApi(Build.VERSION_CODES.N)
    fun tap(targetDescription: String?): Boolean {
        if (targetDescription != null) {
            val node = findBestNode(rootInActiveWindow, targetDescription, needsClick = true)
            if (node != null) return node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        }
        return dispatchTap(screenCenter())
    }

    @RequiresApi(Build.VERSION_CODES.N)
    fun tapAt(x: Float, y: Float): Boolean = dispatchTap(Pair(x, y))

    @RequiresApi(Build.VERSION_CODES.N)
    fun longPress(targetDescription: String?): Boolean {
        if (targetDescription != null) {
            val node = findBestNode(rootInActiveWindow, targetDescription, needsClick = true)
            if (node != null) return node.performAction(AccessibilityNodeInfo.ACTION_LONG_CLICK)
        }
        return dispatchTap(screenCenter(), durationMs = 800)
    }

    // -------------------------------------------------------------------------
    // Dictée / injection de texte
    // -------------------------------------------------------------------------

    fun injectText(text: String): Boolean {
        // 1. Cherche le champ focalisé
        val focused = findFocusedEditableNode(rootInActiveWindow)
            ?: findFirstEditableNode(rootInActiveWindow)
            ?: return false

        val args = Bundle()
        args.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
        return focused.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
    }

    fun appendText(text: String): Boolean {
        val focused = findFocusedEditableNode(rootInActiveWindow)
            ?: findFirstEditableNode(rootInActiveWindow)
            ?: return false

        val current = focused.text?.toString() ?: ""
        val args = Bundle()
        args.putCharSequence(
            AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
            if (current.isEmpty()) text else "$current $text"
        )
        return focused.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
    }

    fun clearText(): Boolean {
        val focused = findFocusedEditableNode(rootInActiveWindow)
            ?: findFirstEditableNode(rootInActiveWindow)
            ?: return false
        val args = Bundle()
        args.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, "")
        return focused.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
    }

    fun deleteLastWord(): Boolean {
        val focused = findFocusedEditableNode(rootInActiveWindow)
            ?: return false
        val current = focused.text?.toString() ?: return false
        val trimmed = current.trimEnd()
        val lastSpace = trimmed.lastIndexOf(' ')
        val newText = if (lastSpace >= 0) trimmed.substring(0, lastSpace) else ""
        val args = Bundle()
        args.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, newText)
        return focused.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
    }

    fun submitText(): Boolean {
        // Cherche un bouton Envoyer / Send / Valider visible
        val sendNode = findBestNode(rootInActiveWindow, "envoyer send valider ok soumettre submit", needsClick = true)
        if (sendNode != null) return sendNode.performAction(AccessibilityNodeInfo.ACTION_CLICK)

        // Sinon simule la touche Entrée sur le champ focalisé
        val focused = findFocusedEditableNode(rootInActiveWindow) ?: return false
        return focused.performAction(AccessibilityNodeInfo.ACTION_NEXT_AT_MOVEMENT_GRANULARITY)
    }

    // -------------------------------------------------------------------------
    // Lecture de l'écran
    // -------------------------------------------------------------------------

    /** Retourne tout le texte lisible visible sur l'écran courant. */
    fun readScreenText(): String {
        val texts = mutableListOf<String>()
        collectText(rootInActiveWindow, texts)
        return if (texts.isEmpty()) "Écran vide." else texts.joinToString(". ")
    }

    /** Retourne le texte de l'élément actuellement focalisé. */
    fun readFocusedText(): String {
        val focused = findFocusedEditableNode(rootInActiveWindow)
            ?: rootInActiveWindow?.findFocus(AccessibilityNodeInfo.FOCUS_ACCESSIBILITY)
            ?: return "Aucun élément focalisé."
        val text = focused.text?.toString()
        val desc = focused.contentDescription?.toString()
        return listOfNotNull(text, desc).filter { it.isNotEmpty() }.joinToString(" — ")
            .ifEmpty { "Aucun texte sur cet élément." }
    }

    /** Retourne les notifications actives sous forme de texte lisible. */
    fun readNotifications(): String {
        val texts = mutableListOf<String>()
        for (window in windows ?: emptyList()) {
            if (window.type == android.view.accessibility.AccessibilityWindowInfo.TYPE_SYSTEM) {
                collectText(window.root, texts)
            }
        }
        return if (texts.isEmpty()) "Aucune notification visible." else texts.joinToString(". ")
    }

    // -------------------------------------------------------------------------
    // Arbre UI pour résolution intelligente (Tier 2 / Tier 3)
    // -------------------------------------------------------------------------

    /**
     * Retourne un JSON array de tous les nœuds interactifs ou avec du texte.
     * N'inclut PAS le contenu des champs de saisie (vie privée).
     */
    fun getScreenNodes(): String {
        val array = JSONArray()
        collectNodes(rootInActiveWindow, array, depth = 0)
        return array.toString()
    }

    private fun collectNodes(node: AccessibilityNodeInfo?, out: JSONArray, depth: Int) {
        if (node == null || depth > 10) return

        val text = node.text?.toString()
        val desc = node.contentDescription?.toString()
        val isEditable = node.isEditable
        val isClickable = node.isClickable
        val isScrollable = node.isScrollable

        val hasLabel = !text.isNullOrBlank() || !desc.isNullOrBlank()

        if (hasLabel || isClickable || isEditable || isScrollable) {
            val rect = android.graphics.Rect()
            node.getBoundsInScreen(rect)

            val obj = JSONObject()
            // Pour les champs éditables on n'envoie pas le contenu — seulement le hint/description
            obj.put("text", if (isEditable) (desc ?: node.hintText?.toString() ?: "") else (text ?: ""))
            obj.put("desc", desc ?: "")
            obj.put("class", node.className?.toString() ?: "")
            obj.put("clickable", isClickable)
            obj.put("editable", isEditable)
            obj.put("scrollable", isScrollable)
            obj.put("focused", node.isFocused)
            obj.put("left", rect.left)
            obj.put("top", rect.top)
            obj.put("right", rect.right)
            obj.put("bottom", rect.bottom)
            out.put(obj)
        }

        for (i in 0 until node.childCount) {
            collectNodes(node.getChild(i), out, depth + 1)
        }
    }

    // -------------------------------------------------------------------------
    // Utilitaires privés
    // -------------------------------------------------------------------------

    private fun collectText(node: AccessibilityNodeInfo?, out: MutableList<String>) {
        if (node == null) return
        val text = node.text?.toString()
        val desc = node.contentDescription?.toString()
        if (!text.isNullOrBlank()) out.add(text)
        else if (!desc.isNullOrBlank()) out.add(desc)
        for (i in 0 until node.childCount) collectText(node.getChild(i), out)
    }

    /**
     * Trouve le meilleur nœud correspondant à [query] par overlap de mots.
     * Score pondéré par le type (clickable/editable).
     */
    private fun findBestNode(
        root: AccessibilityNodeInfo?,
        query: String,
        needsClick: Boolean,
    ): AccessibilityNodeInfo? {
        if (root == null) return null
        val queryWords = query.lowercase().split(Regex("\\s+")).filter { it.length > 1 }.toSet()
        var bestNode: AccessibilityNodeInfo? = null
        var bestScore = 0.0

        fun score(node: AccessibilityNodeInfo): Double {
            if (needsClick && !node.isClickable && !node.isEditable) return 0.0
            val label = listOfNotNull(
                node.text?.toString(),
                node.contentDescription?.toString(),
            ).joinToString(" ").lowercase()
            if (label.isBlank()) return 0.0
            val labelWords = label.split(Regex("\\s+")).filter { it.length > 1 }.toSet()
            val overlap = queryWords.intersect(labelWords).size.toDouble()
            var s = overlap / queryWords.size.coerceAtLeast(1)
            if (label.contains(query.lowercase())) s += 0.3
            if (node.isClickable) s += 0.05
            if (node.isFocused) s += 0.1
            return s
        }

        fun visit(node: AccessibilityNodeInfo) {
            val s = score(node)
            if (s > bestScore) { bestScore = s; bestNode = node }
            for (i in 0 until node.childCount) {
                val child = node.getChild(i) ?: continue
                visit(child)
            }
        }

        visit(root)
        return if (bestScore > 0.15) bestNode else null
    }

    private fun findFocusedEditableNode(root: AccessibilityNodeInfo?): AccessibilityNodeInfo? {
        if (root == null) return null
        if (root.isFocused && root.isEditable) return root
        for (i in 0 until root.childCount) {
            val found = findFocusedEditableNode(root.getChild(i))
            if (found != null) return found
        }
        return null
    }

    private fun findFirstEditableNode(root: AccessibilityNodeInfo?): AccessibilityNodeInfo? {
        if (root == null) return null
        if (root.isEditable) return root
        for (i in 0 until root.childCount) {
            val found = findFirstEditableNode(root.getChild(i))
            if (found != null) return found
        }
        return null
    }

    @RequiresApi(Build.VERSION_CODES.N)
    private fun dispatchSwipe(downward: Boolean): Boolean {
        val (w, h) = screenSize()
        val cx = w / 2f
        val startY = if (downward) h * 0.3f else h * 0.7f
        val endY   = if (downward) h * 0.7f else h * 0.3f
        val path = Path().apply { moveTo(cx, startY); lineTo(cx, endY) }
        return dispatchGesture(
            GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, 400))
                .build(), null, null
        )
    }

    @RequiresApi(Build.VERSION_CODES.N)
    private fun dispatchHorizontalSwipe(toLeft: Boolean): Boolean {
        val (w, h) = screenSize()
        val cy = h / 2f
        val startX = if (toLeft) w * 0.75f else w * 0.25f
        val endX   = if (toLeft) w * 0.25f else w * 0.75f
        val path = Path().apply { moveTo(startX, cy); lineTo(endX, cy) }
        return dispatchGesture(
            GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, 300))
                .build(), null, null
        )
    }

    @RequiresApi(Build.VERSION_CODES.N)
    private fun dispatchTap(point: Pair<Float, Float>, durationMs: Long = 50): Boolean {
        val path = Path().apply { moveTo(point.first, point.second) }
        return dispatchGesture(
            GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, durationMs))
                .build(), null, null
        )
    }

    private fun screenSize(): Pair<Float, Float> {
        val wm = getSystemService(WINDOW_SERVICE) as WindowManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val b = wm.currentWindowMetrics.bounds
            Pair(b.width().toFloat(), b.height().toFloat())
        } else {
            val m = DisplayMetrics()
            @Suppress("DEPRECATION")
            wm.defaultDisplay.getRealMetrics(m)
            Pair(m.widthPixels.toFloat(), m.heightPixels.toFloat())
        }
    }

    private fun screenCenter(): Pair<Float, Float> {
        val (w, h) = screenSize()
        return Pair(w / 2f, h / 2f)
    }
}
