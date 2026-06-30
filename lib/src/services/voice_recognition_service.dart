import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

/// Gère la reconnaissance vocale locale en écoute continue.
/// Rien n'est enregistré ni transmis — traitement par le moteur de l'appareil.
class VoiceRecognitionService {
  static const MethodChannel _platform =
      MethodChannel('ca.thinkphone.navigation_vocale/system');
  final SpeechToText _stt = SpeechToText();

  bool _isInitialized = false;
  bool _isMuted = false;
  bool _isActive = false;
  String? _localeId;
  List<LocaleName> _availableLocales = [];

  final _commandStream    = StreamController<String>.broadcast();
  final _partialStream    = StreamController<String>.broadcast();
  final _soundLevelStream = StreamController<double>.broadcast();

  Stream<String> get onSpeechResult  => _commandStream.stream;
  Stream<String> get onPartialResult => _partialStream.stream;
  Stream<double> get onSoundLevel    => _soundLevelStream.stream;

  bool get isMicEnabled => !_isMuted;
  bool get isListening  => _stt.isListening;
  String? get currentLocale => _localeId;
  List<LocaleName> get availableLocales => _availableLocales;

  List<LocaleName> get availableFrenchLocales =>
      _availableLocales.where((l) => l.localeId.toLowerCase().startsWith('fr')).toList();

  Future<bool> initialize() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      debugPrint('[NavVocale] ❌ Permission micro refusée ($micStatus)');
      return false;
    }

    _isInitialized = await _stt.initialize(
      onError: (e) {
        debugPrint('[NavVocale] STT erreur: ${e.errorMsg} (permanent: ${e.permanent})');
        // Certaines erreurs sont permanentes (ex: pas de réseau) — on ne boucle pas
        if (!e.permanent) _restartIfNeeded();
      },
      onStatus: (s) {
        debugPrint('[NavVocale] STT statut: $s');
        if (s == 'done' || s == 'notListening') _restartIfNeeded();
      },
      debugLogging: kDebugMode,
    );

    if (_isInitialized) {
      await _selectBestLocale();
    } else {
      debugPrint('[NavVocale] ❌ STT initialize() a retourné false — moteur absent ?');
    }

    return _isInitialized;
  }

  Future<void> _selectBestLocale() async {
    // Valeur par défaut même si non listée
    _localeId = 'fr-CA';
    try {
      _availableLocales = await _stt.locales();
      final fr = _availableLocales
          .where((l) => l.localeId.toLowerCase().startsWith('fr'))
          .toList();

      debugPrint('[NavVocale] ${_availableLocales.length} locales totales, '
          '${fr.length} françaises : ${fr.map((l) => l.localeId).join(', ')}');

      if (fr.isNotEmpty) {
        // Priorité : fr-CA > fr-FR > fr-BE > toute fr-*
        final frCA = fr.where((l) => l.localeId.toLowerCase().contains('-ca'));
        final frFR = fr.where((l) => l.localeId.toLowerCase().contains('-fr'));
        _localeId = frCA.isNotEmpty
            ? frCA.first.localeId
            : frFR.isNotEmpty
                ? frFR.first.localeId
                : fr.first.localeId;
        debugPrint('[NavVocale] ✅ Locale choisie : $_localeId');
      } else {
        debugPrint('[NavVocale] ⚠️ Aucune locale française ! '
            'Installe le pack français dans Paramètres > Système > '
            'Langue et saisie > Reconnaissance vocale hors ligne');
      }
    } catch (e) {
      debugPrint('[NavVocale] Impossible de lister les locales : $e');
    }
  }

  Future<void> startListening() async {
    if (!_isInitialized || _stt.isListening) return;
    _isActive = true;
    await _startForegroundService();

    try {
      await _stt.listen(
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty) {
            _partialStream.add(result.recognizedWords);
          }
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            _commandStream.add(result.recognizedWords);
            _partialStream.add('');
          }
        },
        // Sessions de 20s — plus courtes = plus fiables sur Android.
        // Le moteur STT Android peut ignorer listenFor > ~60s sur certains appareils.
        listenFor: const Duration(seconds: 20),
        // 1.5s de silence = fin de commande. Assez court pour ne pas frustrer,
        // assez long pour les commandes composées.
        pauseFor: const Duration(milliseconds: 1500),
        localeId: _localeId,
        onSoundLevelChange: (level) {
          // Normalise 0..10 → 0..1
          _soundLevelStream.add((level / 10.0).clamp(0.0, 1.0));
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          // confirmation = mode commandes courtes : plus rapide que dictation
          listenMode: ListenMode.confirmation,
          autoPunctuation: false,
        ),
      );
    } catch (e) {
      debugPrint('[NavVocale] Échec listen(): $e');
      _restartIfNeeded();
    }
  }

  void _restartIfNeeded() {
    if (!_isInitialized || !_isActive) return;
    // 100ms au lieu de 300ms → reprise plus rapide entre commandes
    Future.delayed(const Duration(milliseconds: 100), () {
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
    if (_isActive && !_stt.isListening) startListening();
  }

  void disableMic() => _isMuted = true;

  Future<void> _startForegroundService() async {
    try { await _platform.invokeMethod('startForegroundService'); }
    catch (_) { debugPrint('[NavVocale] startForegroundService ignoré'); }
  }

  Future<void> _stopForegroundService() async {
    try { await _platform.invokeMethod('stopForegroundService'); }
    catch (_) { debugPrint('[NavVocale] stopForegroundService ignoré'); }
  }

  void dispose() {
    _isActive = false;
    _isMuted = false;
    _commandStream.close();
    _partialStream.close();
    _soundLevelStream.close();
    _stt.cancel();
  }
}
