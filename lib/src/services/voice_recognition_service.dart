import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceRecognitionService {
  static const MethodChannel _platform =
      MethodChannel('ca.thinkphone.navigation_vocale/system');
  final SpeechToText _stt = SpeechToText();

  bool _isInitialized = false;
  bool _isMuted = false;
  bool _isActive = false;
  bool _localeConfirmed = false;
  String? _localeId;
  List<LocaleName> _availableLocales = [];

  // Compteur de tentatives pour le fallback de locale
  int _localeFallbackStep = 0;
  static const _localeFallbacks = ['fr-CA', 'fr-FR', 'fr', null];

  final _commandStream    = StreamController<String>.broadcast();
  final _partialStream    = StreamController<String>.broadcast();
  final _soundLevelStream = StreamController<double>.broadcast();

  Stream<String> get onSpeechResult  => _commandStream.stream;
  Stream<String> get onPartialResult => _partialStream.stream;
  Stream<double> get onSoundLevel    => _soundLevelStream.stream;

  bool    get isMicEnabled    => !_isMuted;
  bool    get isListening     => _stt.isListening;
  String? get localeId        => _localeId;
  bool    get localeConfirmed => _localeConfirmed;
  List<LocaleName> get availableLocales => _availableLocales;

  void activate()   => _isActive = true;
  void deactivate() => _isActive = false;

  Future<bool> initialize() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      debugPrint('[NavVocale] ❌ Permission micro refusée');
      return false;
    }

    _isInitialized = await _stt.initialize(
      onError: (e) {
        debugPrint('[NavVocale] STT erreur: ${e.errorMsg} (permanent: ${e.permanent})');

        if (e.errorMsg == 'error_language_not_supported') {
          // Essaie la prochaine locale dans la liste
          _localeFallbackStep++;
          if (_localeFallbackStep < _localeFallbacks.length) {
            _localeId = _localeFallbacks[_localeFallbackStep];
            _localeConfirmed = _localeId != null;
            debugPrint('[NavVocale] Locale non supportée → essai: $_localeId');
          } else {
            debugPrint('[NavVocale] ❌ Aucune locale FR supportée par ce moteur STT');
            _partialStream.add('[lang_not_supported]');
          }
          _forceRestart();
          return;
        }

        if (!e.permanent) _scheduleRestart();
      },
      onStatus: (s) {
        debugPrint('[NavVocale] STT statut: $s (isListening=${_stt.isListening})');
        if (s == 'done' || s == 'notListening') _scheduleRestart();
      },
      debugLogging: false,
    );

    if (_isInitialized) {
      await _detectLocale();
      debugPrint('[NavVocale] Locale finale : $_localeId (confirmée: $_localeConfirmed)');
    }
    return _isInitialized;
  }

  Future<void> _detectLocale() async {
    // Commence toujours par fr-CA — Google peut le reconnaître en ligne
    // même sans pack hors ligne installé.
    _localeId = 'fr-CA';
    _localeConfirmed = true;
    _localeFallbackStep = 0;

    try {
      _availableLocales = await _stt.locales();
      debugPrint('[NavVocale] ${_availableLocales.length} locales listées (hors ligne seulement) :');
      for (final l in _availableLocales) {
        debugPrint('[NavVocale]   ${l.localeId} — ${l.name}');
      }
      // Si une locale FR est hors ligne, on la préfère (plus rapide/fiable)
      final frOffline = _availableLocales
          .where((l) => l.localeId.toLowerCase().startsWith('fr'))
          .toList();
      if (frOffline.isNotEmpty) {
        _localeId = frOffline.first.localeId;
        debugPrint('[NavVocale] ✅ Locale FR hors ligne dispo : $_localeId');
      } else {
        debugPrint('[NavVocale] ℹ Pas de FR hors ligne → fr-CA en ligne (LTE OK)');
      }
    } catch (e) {
      debugPrint('[NavVocale] Impossible de lister les locales : $e');
    }
  }

  Future<void> startListening() async {
    if (!_isInitialized || _isMuted) return;

    // Annule toujours l'écoute précédente — évite l'état périmé (_stt.isListening stale)
    await _stt.cancel();

    if (!_isActive) return;

    try {
      debugPrint('[NavVocale] Démarrage écoute — locale: $_localeId');
      await _stt.listen(
        onResult: (result) {
          debugPrint('[NavVocale] Résultat: "${result.recognizedWords}" '
              '(final: ${result.finalResult})');
          if (result.recognizedWords.isNotEmpty) {
            _partialStream.add(result.recognizedWords);
          }
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            _commandStream.add(result.recognizedWords);
            _partialStream.add('');
          }
        },
        onSoundLevelChange: (level) {
          _soundLevelStream.add(((level + 2.0) / 12.0).clamp(0.0, 1.0));
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
          autoPunctuation: false,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(milliseconds: 1500),
          localeId: _localeId,
        ),
      );
    } catch (e) {
      debugPrint('[NavVocale] Échec listen(): $e');
      _scheduleRestart();
    }
  }

  // Restart normal avec délai — après fin de session normale
  void _scheduleRestart() {
    if (!_isInitialized || !_isActive || _isMuted) return;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_isActive && !_isMuted) startListening();
    });
  }

  // Restart immédiat — après changement de locale (error_language_not_supported)
  void _forceRestart() {
    if (!_isInitialized || !_isActive || _isMuted) return;
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_isActive && !_isMuted) startListening();
    });
  }

  Future<void> stopListening() async {
    _isActive = false;
    await _stt.stop();
    await _stt.cancel();
  }

  void enableMic() {
    _isMuted = false;
    if (_isActive) startListening();
  }

  void disableMic() => _isMuted = true;

  Future<void> startForegroundService() async {
    try { await _platform.invokeMethod('startForegroundService'); }
    catch (e) { debugPrint('[NavVocale] startForegroundService: $e'); }
  }

  Future<void> stopForegroundService() async {
    try { await _platform.invokeMethod('stopForegroundService'); }
    catch (e) { debugPrint('[NavVocale] stopForegroundService: $e'); }
  }

  void dispose() {
    _isActive = false;
    _commandStream.close();
    _partialStream.close();
    _soundLevelStream.close();
    _stt.cancel();
  }
}
