import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/navigation_action.dart';
import '../models/screen_node.dart';

class SystemNavigationService {
  static const _channel = MethodChannel('ca.thinkphone.navigation_vocale/system');

  // Navigation
  Future<NavigationAction> performHome()       => _call('performHome');
  Future<NavigationAction> performBack()       => _call('performBack');
  Future<NavigationAction> performRecents()    => _call('performRecents');
  Future<NavigationAction> openNotifications() => _call('openNotifications');
  Future<NavigationAction> closeCurrentApp()   => _call('closeCurrentApp');
  Future<NavigationAction> openApp(String name) => _call('openApp', {'name': name});

  // Gestes
  Future<NavigationAction> scrollDown()  => _call('scrollDown');
  Future<NavigationAction> scrollUp()    => _call('scrollUp');
  Future<NavigationAction> swipeLeft()   => _call('swipeLeft');
  Future<NavigationAction> swipeRight()  => _call('swipeRight');
  Future<NavigationAction> tap({String? targetDescription}) =>
      _call('tap', if (targetDescription != null) {'target': targetDescription});
  Future<NavigationAction> tapAt(double x, double y) =>
      _call('tapAt', {'x': x, 'y': y});
  Future<NavigationAction> longPress({String? targetDescription}) =>
      _call('longPress', if (targetDescription != null) {'target': targetDescription});

  // Texte
  Future<NavigationAction> injectText(String text) => _call('injectText', {'text': text});
  Future<NavigationAction> appendText(String text)  => _call('appendText', {'text': text});
  Future<NavigationAction> submitText()             => _call('submitText');
  Future<NavigationAction> clearText()              => _call('clearText');
  Future<NavigationAction> deleteLastWord()         => _call('deleteLastWord');

  // Lecture d'écran
  Future<String> readScreenText() async {
    try {
      return await _channel.invokeMethod<String>('readScreenText') ?? '';
    } on PlatformException catch (e) {
      return e.message ?? '';
    } on MissingPluginException {
      return 'Service d\'accessibilité non activé.';
    }
  }

  Future<String> readFocusedText() async {
    try {
      return await _channel.invokeMethod<String>('readFocusedText') ?? '';
    } on PlatformException catch (e) {
      return e.message ?? '';
    } on MissingPluginException {
      return 'Service d\'accessibilité non activé.';
    }
  }

  Future<String> readNotificationsText() async {
    try {
      return await _channel.invokeMethod<String>('readNotifications') ?? 'Aucune notification.';
    } on PlatformException catch (e) {
      return e.message ?? '';
    } on MissingPluginException {
      return 'Service d\'accessibilité non activé.';
    }
  }

  // Arbre UI pour résolution intelligente
  Future<List<ScreenNode>> getScreenNodes() async {
    try {
      final json = await _channel.invokeMethod<String>('getScreenNodes') ?? '[]';
      final list = jsonDecode(json) as List;
      return list
          .map((e) => ScreenNode.fromMap(e as Map<Object?, Object?>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // Accessibilité
  Future<bool> isAccessibilityEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openAccessibilitySettings() =>
      _channel.invokeMethod('openAccessibilitySettings');

  Future<NavigationAction> _call(String method, [Map<String, dynamic>? args]) async {
    try {
      final ok = await _channel.invokeMethod<bool>(method, args);
      return ok == true
          ? NavigationAction.success
          : NavigationAction.failure('Action non exécutée');
    } on PlatformException catch (e) {
      return NavigationAction.failure(e.message ?? 'Erreur');
    } on MissingPluginException {
      return NavigationAction.notSupported(
          'Activez le service d\'accessibilité dans Paramètres > Accessibilité.');
    }
  }
}
