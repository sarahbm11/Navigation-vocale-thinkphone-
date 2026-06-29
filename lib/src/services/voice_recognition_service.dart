import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

/// Gère la reconnaissance vocale locale en écoute continue.
/// Rien n'est enregistré ni transmis — traitement par le moteur de l'appareil.
class VoiceRecognitionService {
  final SpeechToText _stt = SpeechToText();

  bool _isInitialized = false;
  bool _micEnabled = true;
  String? _localeId;

  final _commandStream = StreamController<String>.broadcast();

  /// Flux des textes reconnus en temps réel.
  Stream<String> get onSpeechResult => _commandStream.stream;

  bool get isMicEnabled => _micEnabled;
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
    if (!_isInitialized || !_micEnabled || _stt.isListening) return;

    try {
      await _stt.listen(
        onResult: (result) {
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            _commandStream.add(result.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
        localeId: _localeId,
        listenOptions: SpeechListenOptions(
          partialResults: false,
          cancelOnError: false,
          // Écoute en continu : ne s'arrête pas au premier mot.
          listenMode: ListenMode.dictation,
        ),
      );
    } catch (e) {
      debugPrint('[NavVocale] Échec listen(): $e');
      _restartIfNeeded();
    }
  }

  /// Relance l'écoute après un court délai si le micro est toujours actif.
  void _restartIfNeeded() {
    if (!_micEnabled || !_isInitialized) return;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_micEnabled && _isInitialized && !_stt.isListening) {
        startListening();
      }
    });
  }

  Future<void> stopListening() async {
    await _stt.stop();
  }

  void enableMic() {
    _micEnabled = true;
    startListening();
  }

  void disableMic() {
    _micEnabled = false;
    stopListening();
  }

  void dispose() {
    _micEnabled = false;
    _commandStream.close();
    _stt.cancel();
  }
}
