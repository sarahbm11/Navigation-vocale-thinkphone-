import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

/// Gère la reconnaissance vocale locale en écoute continue.
/// Rien n'est enregistré ni transmis — traitement par le moteur de l'appareil.
class VoiceRecognitionService {
  static const MethodChannel _platform = MethodChannel('ca.thinkphone.navigation_vocale/system');
  final SpeechToText _stt = SpeechToText();

  bool _isInitialized = false;
  bool _isMuted = false;
  bool _isActive = false;
  String? _localeId;

  final _commandStream = StreamController<String>.broadcast();

  /// Flux des textes reconnus en temps réel.
  Stream<String> get onSpeechResult => _commandStream.stream;

  bool get isMicEnabled => !_isMuted;
  bool get isListening => _stt.isListening;

  Future<bool> initialize() async {
    // 1. Demande explicite de la permission micro (indispensable sur Android).
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      debugPrint('[NavVocale] Permission micro refusée ($micStatus)');
      return false;
    }

    // 2. Initialise le moteur STT. On relance l'écoute sur chaque arrêt/erreur.
    _isInitialized = await _stt.initialize(
      onError: (e) {
        debugPrint('[NavVocale] Erreur STT: ${e.errorMsg}');
        _restartIfNeeded();
      },
      onStatus: (s) {
        debugPrint('[NavVocale] STT statut: $s');
        // 'done' / 'notListening' = le moteur s'est arrêté → on relance.
        if (s == 'done' || s == 'notListening') {
          _restartIfNeeded();
        }
      },
      debugLogging: false,
    );

    // 3. Choisit une locale française disponible (sinon défaut système).
    if (_isInitialized) {
      try {
        final locales = await _stt.locales();
        final fr = locales.where((l) => l.localeId.toLowerCase().startsWith('fr'));
        if (fr.isNotEmpty) {
          // Préfère fr_CA si présent, sinon la première locale fr.
          final caMatch = fr.where((l) => l.localeId.toLowerCase().contains('ca'));
          _localeId = (caMatch.isNotEmpty ? caMatch.first : fr.first).localeId;
          debugPrint('[NavVocale] Locale STT: $_localeId');
        }
      } catch (e) {
        debugPrint('[NavVocale] Impossible de lister les locales: $e');
      }
    }

    return _isInitialized;
  }

  Future<void> startListening() async {
    if (!_isInitialized || _stt.isListening) return;
    _isActive = true;

    await _startForegroundService();

    try {
      await _stt.listen(
        onResult: (result) {
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            _commandStream.add(result.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 180),
        pauseFor: const Duration(seconds: 20),
        localeId: _localeId,
        listenOptions: SpeechListenOptions(
          partialResults: false,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
          autoPunctuation: false,
        ),
      );
    } catch (e) {
      debugPrint('[NavVocale] Échec listen(): $e');
      _restartIfNeeded();
    }
  }

  /// Relance l'écoute après un court délai si le service est actif et non coupé.
  void _restartIfNeeded() {
    if (!_isInitialized || !_isActive) return;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_isActive && _isInitialized && !_stt.isListening) {
        startListening();
      }
    });
  }

  Future<void> stopListening() async {
    _isActive = false;
    await _stt.stop();
    await _stt.cancel();
    await _stopForegroundService();
  }

  void enableMic() {
    _isMuted = false;
    if (_isActive && !_stt.isListening) {
      startListening();
    }
  }

  void disableMic() {
    _isMuted = true;
  }

  Future<void> _startForegroundService() async {
    try {
      await _platform.invokeMethod('startForegroundService');
    } catch (_) {
      // ignore: avoid_print
      debugPrint('[NavVocale] Impossible de démarrer le service de premier plan');
    }
  }

  Future<void> _stopForegroundService() async {
    try {
      await _platform.invokeMethod('stopForegroundService');
    } catch (_) {
      // ignore: avoid_print
      debugPrint("[NavVocale] Impossible d'arrêter le service de premier plan");
    }
  }

  void dispose() {
    _isActive = false;
    _isMuted = false;
    _commandStream.close();
    _stt.cancel();
  }
}
