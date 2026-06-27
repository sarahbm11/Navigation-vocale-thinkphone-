import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Service de synthèse vocale (Text-to-Speech).
/// Lit à voix haute le texte de l'écran quand l'utilisateur le demande.
/// Aucune donnée n'est envoyée à l'extérieur.
class TtsService {
  final FlutterTts _tts = FlutterTts();

  double _rate = 0.5;   // 0.0 – 1.0
  double _volume = 1.0; // 0.0 – 1.0
  double _pitch = 1.0;

  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;

  Future<void> initialize() async {
    await _tts.setLanguage('fr-CA');
    await _tts.setSpeechRate(_rate);
    await _tts.setVolume(_volume);
    await _tts.setPitch(_pitch);
    await _tts.awaitSpeakCompletion(false);

    _tts.setStartHandler(() => _isSpeaking = true);
    _tts.setCompletionHandler(() => _isSpeaking = false);
    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      debugPrint('[TTS] Erreur: $msg');
    });
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  Future<void> faster() async {
    _rate = (_rate + 0.1).clamp(0.1, 1.0);
    await _tts.setSpeechRate(_rate);
  }

  Future<void> slower() async {
    _rate = (_rate - 0.1).clamp(0.1, 1.0);
    await _tts.setSpeechRate(_rate);
  }

  Future<void> louder() async {
    _volume = (_volume + 0.15).clamp(0.0, 1.0);
    await _tts.setVolume(_volume);
  }

  Future<void> quieter() async {
    _volume = (_volume - 0.15).clamp(0.0, 1.0);
    await _tts.setVolume(_volume);
  }

  void dispose() => _tts.stop();
}
