import 'package:flutter/services.dart';
import '../models/navigation_action.dart';

/// Interagit avec le système Android via le canal de plateforme.
/// Utilise AccessibilityService pour les gestes système.
class SystemNavigationService {
  static const _channel = MethodChannel('ca.thinkphone.navigation_vocale/system');

  Future<NavigationAction> performHome() => _call('performHome');
  Future<NavigationAction> performBack() => _call('performBack');
  Future<NavigationAction> performRecents() => _call('performRecents');
  Future<NavigationAction> openNotifications() => _call('openNotifications');
  Future<NavigationAction> closeCurrentApp() => _call('closeCurrentApp');

  Future<NavigationAction> openApp(String appName) =>
      _call('openApp', {'name': appName});

  Future<NavigationAction> scrollDown() => _call('scrollDown');
  Future<NavigationAction> scrollUp() => _call('scrollUp');
  Future<NavigationAction> swipeLeft() => _call('swipeLeft');
  Future<NavigationAction> swipeRight() => _call('swipeRight');

  Future<NavigationAction> tap({String? targetDescription}) =>
      _call('tap', if (targetDescription != null) {'target': targetDescription});

  Future<NavigationAction> longPress({String? targetDescription}) =>
      _call('longPress', if (targetDescription != null) {'target': targetDescription});

  Future<bool> isAccessibilityEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAccessibilityEnabled');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openAccessibilitySettings() =>
      _channel.invokeMethod('openAccessibilitySettings');

  Future<NavigationAction> _call(String method, [Map<String, dynamic>? args]) async {
    try {
      final result = await _channel.invokeMethod<bool>(method, args);
      return result == true
          ? NavigationAction.success
          : NavigationAction.failure('Action non exécutée');
    } on PlatformException catch (e) {
      return NavigationAction.failure(e.message ?? 'Erreur inconnue');
    } on MissingPluginException {
      return NavigationAction.notSupported(
          'AccessibilityService non activé. Activez-le dans Paramètres > Accessibilité.');
    }
  }
}
