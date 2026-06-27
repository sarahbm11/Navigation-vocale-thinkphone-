import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Gère la reconnaissance vocale locale.
/// Rien n'est enregistré ni transmis — traitement 100 % sur l'appareil.
class VoiceRecognitionService {
  final SpeechToText _stt = SpeechToText();

  bool _isInitialized = false;
  bool _micEnabled = true;

  final _commandStream = StreamController<String>.broadcast();

  /// Flux des textes reconnus en temps réel.
  Stream<String> get onSpeechResult => _commandStream.stream;

  bool get isMicEnabled => _micEnabled;
  bool get isListening => _stt.isListening;

  Future<bool> initialize() async {
    _isInitialized = await _stt.initialize(
      onError: (e) => debugPrint('[NavVocale] Erreur STT: ${e.errorMsg}'),
      onStatus: (s) => debugPrint('[NavVocale] STT statut: $s'),
      debugLogging: false,
    );
    return _isInitialized;
  }

  Future<void> startListening() async {
    if (!_isInitialized || !_micEnabled || _stt.isListening) return;

    await _stt.listen(
      onResult: (result) {
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          _commandStream.add(result.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'fr_CA',
      partialResults: false,
      cancelOnError: false,
    );
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
    _commandStream.close();
    _stt.cancel();
  }
}
