import 'dart:async';
import 'package:flutter/foundation.dart';
import 'models/voice_command.dart';
import 'models/navigation_action.dart';
import 'services/voice_recognition_service.dart';
import 'services/system_navigation_service.dart';
import 'utils/command_parser.dart';

/// Point d'entrée principal du SDK Navigation Vocale.
///
/// Usage minimal :
/// ```dart
/// final sdk = NavigationVocaleSDK();
/// await sdk.initialize();
/// sdk.start();
/// ```
class NavigationVocaleSDK {
  final VoiceRecognitionService _voiceService = VoiceRecognitionService();
  final SystemNavigationService _navService = SystemNavigationService();

  StreamSubscription<String>? _speechSub;
  final _commandController = StreamController<VoiceCommand>.broadcast();
  final _actionController = StreamController<NavigationAction>.broadcast();

  bool _isRunning = false;

  /// Flux des commandes vocales reconnues.
  Stream<VoiceCommand> get onCommand => _commandController.stream;

  /// Flux des résultats d'actions de navigation.
  Stream<NavigationAction> get onAction => _actionController.stream;

  bool get isRunning => _isRunning;
  bool get isMicEnabled => _voiceService.isMicEnabled;

  /// Initialise le SDK et vérifie les permissions.
  /// Retourne [true] si prêt à démarrer.
  Future<bool> initialize() async {
    final ok = await _voiceService.initialize();
    if (!ok) {
      debugPrint('[NavVocale] Impossible d\'initialiser la reconnaissance vocale.');
    }
    return ok;
  }

  /// Démarre l'écoute vocale continue.
  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;

    _speechSub = _voiceService.onSpeechResult.listen(_handleSpeech);
    await _voiceService.startListening();

    // Redémarre automatiquement quand l'écoute s'arrête (silence ou pause)
    _voiceService.onSpeechResult.listen((_) {}, onDone: _restartIfNeeded);
  }

  /// Arrête complètement l'écoute.
  Future<void> stop() async {
    _isRunning = false;
    await _speechSub?.cancel();
    await _voiceService.stopListening();
  }

  /// Coupe le micro (vie privée) sans fermer le SDK.
  void muteMic() => _voiceService.disableMic();

  /// Réactive le micro.
  void unmuteMic() {
    _voiceService.enableMic();
  }

  Future<void> _handleSpeech(String text) async {
    final command = CommandParser.parse(text);
    _commandController.add(command);

    final action = await _executeCommand(command);
    if (action != null) _actionController.add(action);

    // Reprend l'écoute après chaque commande
    if (_isRunning && _voiceService.isMicEnabled) {
      await _voiceService.startListening();
    }
  }

  Future<NavigationAction?> _executeCommand(VoiceCommand cmd) async {
    switch (cmd.type) {
      case CommandType.home:
        return _navService.performHome();
      case CommandType.back:
        return _navService.performBack();
      case CommandType.recents:
        return _navService.performRecents();
      case CommandType.notifications:
        return _navService.openNotifications();
      case CommandType.closeApp:
        return _navService.closeCurrentApp();
      case CommandType.openApp:
        if (cmd.parameter != null) return _navService.openApp(cmd.parameter!);
        return NavigationAction.failure('Nom d\'application manquant');
      case CommandType.scrollDown:
        return _navService.scrollDown();
      case CommandType.scrollUp:
        return _navService.scrollUp();
      case CommandType.swipeLeft:
        return _navService.swipeLeft();
      case CommandType.swipeRight:
        return _navService.swipeRight();
      case CommandType.tap:
        return _navService.tap(targetDescription: cmd.parameter);
      case CommandType.longPress:
        return _navService.longPress(targetDescription: cmd.parameter);
      case CommandType.micOff:
        muteMic();
        return null;
      case CommandType.micOn:
        unmuteMic();
        return null;
      case CommandType.stop:
        await stop();
        return null;
      case CommandType.unknown:
        return null;
    }
  }

  Future<void> _restartIfNeeded() async {
    if (_isRunning && _voiceService.isMicEnabled && !_voiceService.isListening) {
      await _voiceService.startListening();
    }
  }

  Future<bool> isAccessibilityEnabled() => _navService.isAccessibilityEnabled();
  Future<void> openAccessibilitySettings() => _navService.openAccessibilitySettings();

  void dispose() {
    stop();
    _voiceService.dispose();
    _commandController.close();
    _actionController.close();
  }
}
