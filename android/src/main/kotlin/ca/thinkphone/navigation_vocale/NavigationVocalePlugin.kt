package ca.thinkphone.navigation_vocale

import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class NavigationVocalePlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "ca.thinkphone.navigation_vocale/system")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        val svc = VoiceNavigationAccessibilityService.instance

        when (call.method) {
            // --- Sans service d'accessibilité ---
            "isAccessibilityEnabled" -> {
                result.success(svc != null)
                return
            }
            "openAccessibilitySettings" -> {
                try {
                    context.startActivity(
                        Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                    result.success(true)
                } catch (e: Exception) {
                    Log.e("NavVocale", "openAccessibilitySettings échoué: ${e.message}")
                    result.success(false)
                }
                return
            }
        }

        if (call.method == "startForegroundService") {
            try {
                val intent = Intent(context, BackgroundSpeechService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    ContextCompat.startForegroundService(context, intent)
                } else {
                    context.startService(intent)
                }
                result.success(true)
            } catch (e: Exception) {
                // ForegroundServiceStartNotAllowedException ou SecurityException
                // → on log mais on ne propage pas l'erreur (évite le crash du process)
                Log.e("NavVocale", "startForegroundService échoué: ${e.message}")
                result.success(false)
            }
            return
        }

        if (call.method == "stopForegroundService") {
            try {
                context.stopService(Intent(context, BackgroundSpeechService::class.java))
                result.success(true)
            } catch (e: Exception) {
                Log.e("NavVocale", "stopForegroundService échoué: ${e.message}")
                result.success(false)
            }
            return
        }

        if (call.method == "canDrawOverlay") {
            val can = Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
                      android.provider.Settings.canDrawOverlays(context)
            result.success(can)
            return
        }

        if (call.method == "requestOverlayPermission") {
            try {
                val intent = Intent(
                    android.provider.Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    android.net.Uri.parse("package:${context.packageName}")
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                result.success(true)
            } catch (e: Exception) {
                result.success(false)
            }
            return
        }

        if (call.method == "startBubble") {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                    !android.provider.Settings.canDrawOverlays(context)) {
                    result.success(false)
                    return
                }
                val intent = Intent(context, FloatingBubbleService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    ContextCompat.startForegroundService(context, intent)
                } else {
                    context.startService(intent)
                }
                result.success(true)
            } catch (e: Exception) {
                Log.e("NavVocale", "startBubble: ${e.message}")
                result.success(false)
            }
            return
        }

        if (call.method == "stopBubble") {
            try {
                context.stopService(Intent(context, FloatingBubbleService::class.java))
                result.success(true)
            } catch (e: Exception) {
                result.success(false)
            }
            return
        }

        if (call.method == "updateBubbleMic") {
            val active = call.argument<Boolean>("active") ?: false
            FloatingBubbleService.updateMicActive(active)
            result.success(true)
            return
        }

        if (svc == null) {
            result.error(
                "ACCESSIBILITY_DISABLED",
                "Activez Navigation Vocale dans Paramètres > Accessibilité",
                null
            )
            return
        }

        when (call.method) {
            // Navigation
            "performHome"       -> result.success(svc.performHome())
            "performBack"       -> result.success(svc.performBack())
            "performRecents"    -> result.success(svc.performRecents())
            "openNotifications" -> result.success(svc.openNotifications())
            "closeCurrentApp"   -> result.success(svc.closeCurrentApp())
            "openApp"           -> result.success(svc.openAppByName(call.argument<String>("name") ?: ""))

            // Gestes
            "scrollDown"  -> result.success(if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) svc.scrollDown() else false)
            "scrollUp"    -> result.success(if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) svc.scrollUp() else false)
            "swipeLeft"   -> result.success(if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) svc.swipeLeft() else false)
            "swipeRight"  -> result.success(if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) svc.swipeRight() else false)
            "tap"         -> result.success(if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) svc.tap(call.argument("target")) else false)
            "tapAt"       -> result.success(
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N)
                    svc.tapAt(
                        (call.argument<Double>("x") ?: 0.0).toFloat(),
                        (call.argument<Double>("y") ?: 0.0).toFloat()
                    )
                else false
            )
            "longPress"   -> result.success(if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) svc.longPress(call.argument("target")) else false)

            // Texte
            "injectText"    -> result.success(svc.injectText(call.argument<String>("text") ?: ""))
            "appendText"    -> result.success(svc.appendText(call.argument<String>("text") ?: ""))
            "submitText"    -> result.success(svc.submitText())
            "clearText"     -> result.success(svc.clearText())
            "deleteLastWord"-> result.success(svc.deleteLastWord())

            // Lecture écran
            "readScreenText"    -> result.success(svc.readScreenText())
            "readFocusedText"   -> result.success(svc.readFocusedText())
            "readNotifications" -> result.success(svc.readNotifications())

            // Arbre UI pour résolution intelligente
            "getScreenNodes"    -> result.success(svc.getScreenNodes())

            else -> result.notImplemented()
        }
    }
}
