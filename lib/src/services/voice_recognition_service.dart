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

  final _commandStream    = StreamController<String>.broadcast();
  final _partialStream    = StreamController<String>.broadcast();
  final _soundLevelStream = StreamController<double>.broadcast();

  Stream<String> get onSpeechResult  => _commandStream.stream;
  Stream<String> get onPartialResult => _partialStream.stream;
  Stream<double> get onSoundLevel    => _soundLevelStream.stream;

  bool    get isMicEnabled => !_isMuted;
  bool    get isListening  => _stt.isListening;
  String? get localeId     => _localeId;
  bool    get localeConfirmed => _localeConfirmed;
  List<LocaleName> get availableLocales => _availableLocales;

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
          debugPrint('[NavVocale] ⚠ Locale $_localeId non supportée — '
              'bascule sur locale système');
          _localeId = null;
          _localeConfirmed = false;
          _partialStream.add('[lang_not_supported]');
        }
        // Relance dans tous les cas non-permanents, avec délai raisonnable
        if (!e.permanent) _scheduleRestart();
      },
      onStatus: (s) {
        debugPrint('[NavVocale] STT statut: $s');
        if (s == 'done' || s == 'notListening') _scheduleRestart();
      },
      debugLogging: false,
    );

    if (_isInitialized) await _detectLocale();
    return _isInitialized;
  }

  Future<void> _detectLocale() async {
    try {
      _availableLocales = await _stt.locales();
      debugPrint('[NavVocale] ${_availableLocales.length} locales dispo :');
      for (final l in _availableLocales) {
        debugPrint('[NavVocale]   ${l.localeId} — ${l.name}');
      }

      final fr = _availableLocales
          .where((l) => l.localeId.toLowerCase().startsWith('fr'))
          .toList();

      if (fr.isNotEmpty) {
        final frCA = fr.where((l) => l.localeId.toLowerCase().contains('-ca'));
        final frFR = fr.where((l) => l.localeId.toLowerCase().contains('-fr'));
        _localeId = frCA.isNotEmpty
            ? frCA.first.localeId
            : frFR.isNotEmpty
                ? frFR.first.localeId
                : fr.first.localeId;
        _localeConfirmed = true;
        debugPrint('[NavVocale] ✅ Locale FR confirmée : $_localeId');
      } else {
        _localeConfirmed = false;
        _localeId = null;
        debugPrint('[NavVocale] ⚠ Aucune locale FR — utilise langue système');
        _partialStream.add('[no_french_locale]');
      }
    } catch (e) {
      debugPrint('[NavVocale] Erreur détection locale : $e');
      _localeConfirmed = false;
      _localeId = null;
    }
  }

  Future<void> startListening() async {
    if (!_isInitialized || _isMuted || _stt.isListening) return;

    try {
      await _stt.listen(
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty) {
            _partialStream.add(result.recognizedWords);
          }
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            debugPrint('[NavVocale] ✅ Reconnu: "${result.recognizedWords}"');
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
          localeId: _localeConfirmed ? _localeId : null,
        ),
      );
    } catch (e) {
      debugPrint('[NavVocale] Échec listen(): $e');
      _scheduleRestart();
    }
  }

  // Délai de 500ms avant restart — évite la boucle rapide qui empêche la reconnaissance
  void _scheduleRestart() {
    if (!_isInitialized || !_isActive || _isMuted) return;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_isActive && !_isMuted && !_stt.isListening) {
        startListening();
      }
    });
  }

  Future<void> stopListening() async {
    _isActive = false;
    await _stt.stop();
    await _stt.cancel();
  }

  void enableMic() {
    _isMuted = false;
    if (_isActive && !_stt.isListening) startListening();
  }

  void disableMic() => _isMuted = true;

  // Appelé une seule fois au démarrage/arrêt du SDK (pas à chaque restart STT)
  Future<void> startForegroundService() async {
    try { await _platform.invokeMethod('startForegroundService'); }
    catch (e) { debugPrint('[NavVocale] startForegroundService: $e'); }
  }

  Future<void> stopForegroundService() async {
    try { await _platform.invokeMethod('stopForegroundService'); }
    catch (e) { debugPrint('[NavVocale] stopForegroundService: $e'); }
  }

  void activate()   => _isActive = true;
  void deactivate() => _isActive = false;

  void dispose() {
    _isActive = false;
    _commandStream.close();
    _partialStream.close();
    _soundLevelStream.close();
    _stt.cancel();
  }
}
