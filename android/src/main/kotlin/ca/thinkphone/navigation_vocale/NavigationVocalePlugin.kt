package ca.thinkphone.navigation_vocale

import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
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
            "isAccessibilityEnabled" -> result.success(svc != null)

            "openAccessibilitySettings" -> {
                val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                result.success(true)
            }

            else -> {
                if (svc == null) {
                    result.error("ACCESSIBILITY_DISABLED",
                        "Activez le service dans Paramètres > Accessibilité > Navigation Vocale", null)
                    return
                }

                val ok: Boolean = when (call.method) {
                    "performHome"       -> svc.performHome()
                    "performBack"       -> svc.performBack()
                    "performRecents"    -> svc.performRecents()
                    "openNotifications" -> svc.openNotifications()
                    "closeCurrentApp"   -> svc.closeCurrentApp()
                    "openApp"           -> svc.openAppByName(call.argument<String>("name") ?: "")
                    "scrollDown"        -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) svc.scrollDown() else false
                    "scrollUp"          -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) svc.scrollUp() else false
                    "swipeLeft"         -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) svc.swipeLeft() else false
                    "swipeRight"        -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) svc.swipeRight() else false
                    "tap"               -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) svc.tap(call.argument("target")) else false
                    "longPress"         -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) svc.longPress(call.argument("target")) else false
                    else -> { result.notImplemented(); return }
                }
                result.success(ok)
            }
        }
    }
}
