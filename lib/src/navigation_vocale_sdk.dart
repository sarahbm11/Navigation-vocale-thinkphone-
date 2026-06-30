import 'dart:async';
import 'package:flutter/foundation.dart';
import 'models/voice_command.dart';
import 'models/navigation_action.dart';
import 'services/voice_recognition_service.dart';
import 'services/system_navigation_service.dart';
import 'services/tts_service.dart';
import 'services/ai_resolver.dart';
import 'services/command_learning_service.dart';
import 'utils/command_parser.dart';
import 'utils/smart_resolver.dart';
import 'utils/phonetic_normalizer.dart';

/// Point d'entrée du SDK Navigation Vocale.
///
/// Architecture à 3 niveaux :
///   Tier 1 — Parseur local (instantané, 100 % hors ligne)
///   Tier 2 — Résolution intelligente sur l'arbre UI Android (hors ligne)
///   Tier 3 — IA Claude API (optionnel, activé explicitement)
class NavigationVocaleSDK {
  final VoiceRecognitionService  _voice    = VoiceRecognitionService();
  final SystemNavigationService  _nav      = SystemNavigationService();
  final TtsService               _tts      = TtsService();
  final SmartResolver            _smart    = SmartResolver();
  final AiResolver               _ai       = AiResolver();
  final CommandLearningService   _learning = CommandLearningService();

  StreamSubscription<String>? _speechSub;
  final _commandCtrl = StreamController<VoiceCommand>.broadcast();
  final _actionCtrl  = StreamController<NavigationAction>.broadcast();
  final _statusCtrl  = StreamController<String>.broadcast();

  bool _running    = false;
  bool _processing = false;

  // Dernière phrase échouée — exposée pour le panneau de correction.
  String? _lastFailedText;

  /// Dernière phrase vocale non reconnue — utile pour proposer une correction.
  String? get lastFailedText => _lastFailedText;

  Stream<VoiceCommand>     get onCommand       => _commandCtrl.stream;
  Stream<NavigationAction> get onAction        => _actionCtrl.stream;
  Stream<String>           get onStatus        => _statusCtrl.stream;
  Stream<String>           get onPartialResult => _voice.onPartialResult;
  Stream<double>           get onSoundLevel    => _voice.onSoundLevel;

  bool get isRunning    => _running;
  bool get isMicEnabled => _voice.isMicEnabled;
  bool get isAiEnabled  => _ai.isEnabled;

  /// Locale STT active (ex. "fr-CA").
  String? get currentLocale => _voice.currentLocale;

  /// Statistiques d'apprentissage persistées.
  Map<String, dynamic> getLearningStats() => _learning.getStats();

  /// Enseigne manuellement une correction (ce que le STT a dit → ce qu'il fallait dire).
  Future<void> teachCorrection(String wrong, String correct) =>
      _learning.learnCorrection(wrong, correct);

  /// Enseigne un alias d'application (nom prononcé → nom réel).
  Future<void> teachAppAlias(String spoken, String realName) =>
      _learning.learnAppAlias(spoken, realName);

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  Future<bool> initialize() async {
    await _learning.initialize();
    final ok = await _voice.initialize();
    await _tts.initialize();
    if (!ok) debugPrint('[NavVocale] STT non disponible');
    return ok;
  }

  // ---------------------------------------------------------------------------
  // Démarrage / arrêt
  // ---------------------------------------------------------------------------

  Future<void> start() async {
    if (_running) return;
    _running = true;
    _speechSub = _voice.onSpeechResult.listen(_handleSpeech);
    await _voice.startListening();
  }

  Future<void> stop() async {
    _running = false;
    await _speechSub?.cancel();
    await _voice.stopListening();
    await _tts.stop();
  }

  void muteMic()   => _voice.disableMic();
  void unmuteMic() { _voice.enableMic(); }

  // ---------------------------------------------------------------------------
  // Commande manuelle (saisie texte)
  // ---------------------------------------------------------------------------

  /// Exécute une commande tapée au clavier.
  /// Supporte les commandes composées : "ouvre WhatsApp et écris à 'Colette': salut"
  Future<void> processTextCommand(String text) async {
    if (text.trim().isEmpty) return;
    final parts = _expandCompoundCommand(text.trim());
    for (var i = 0; i < parts.length; i++) {
      await _handleSpeech(parts[i]);
      if (i < parts.length - 1) {
        await Future.delayed(const Duration(milliseconds: 1200));
      }
    }
  }

  /// Décompose une commande composée en liste de commandes simples.
  /// "ouvre X et écris à 'Y': message" → ["ouvre X", "appuie sur Y", "écris message"]
  List<String> _expandCompoundCommand(String text) {
    final t = text.trim();

    // "écri(t|s|re) à ['"]?Name['"]?: message" → tap + dictate
    final writeToRe = RegExp(
      r"""^écri(?:t|s|re)\s+à\s+[‘"]?([^’":\n]+?)[‘"]?\s*:\s*(.+)$""",
      caseSensitive: false,
    );
    final m = writeToRe.firstMatch(t);
    if (m != null) {
      return [
        'appuie sur ${m.group(1)!.trim()}',
        'écris ${m.group(2)!.trim()}',
      ];
    }

    // Séparateur " et " → commande composée si la 2e partie commence par un verbe d'action
    final etIdx = t.toLowerCase().indexOf(' et ');
    if (etIdx != -1) {
      final first  = t.substring(0, etIdx).trim();
      final second = t.substring(etIdx + 4).trim();
      const verbs = ['ouvr', 'ferme', 'écri', 'tape', 'appuie', 'lis ', 'retour',
                     'accueil', 'envoie', 'défile', 'scroll', 'lancer', 'lance ',
                     'démarr', 'quitt'];
      if (verbs.any((v) => second.toLowerCase().startsWith(v))) {
        return [
          ..._expandCompoundCommand(first),
          ..._expandCompoundCommand(second),
        ];
      }
    }

    return [t];
  }

  // ---------------------------------------------------------------------------
  // Activer l'IA (Tier 3) — opt-in explicite
  // ---------------------------------------------------------------------------

  /// Active le Tier 3 avec la clé API Anthropic fournie.
  /// Seuls les labels UI visibles + la commande vocale sont envoyés.
  void enableAi(String apiKey) => _ai.enable(apiKey);
  void disableAi()              => _ai.disable();

  // ---------------------------------------------------------------------------
  // Bulle flottante
  // ---------------------------------------------------------------------------

  /// Vérifie si l'app a la permission SYSTEM_ALERT_WINDOW (overlay).
  Future<bool> canDrawOverlay() async {
    try {
      return await _nav.invoke<bool>('canDrawOverlay') ?? false;
    } catch (_) { return false; }
  }

  /// Ouvre les paramètres système pour accorder la permission overlay.
  Future<void> requestOverlayPermission() =>
      _nav.invoke('requestOverlayPermission');

  /// Démarre le service de bulle flottante.
  /// Retourne true si le service a démarré avec succès.
  Future<bool> startFloatingBubble() async {
    try {
      return await _nav.invoke<bool>('startBubble') ?? false;
    } catch (_) { return false; }
  }

  /// Arrête le service de bulle flottante.
  Future<void> stopFloatingBubble() => _nav.invoke('stopBubble');

  /// Met à jour l'état du micro (et optionnellement la dernière commande) dans la bulle.
  Future<void> updateBubbleMic({required bool active, String? lastCmd}) =>
      _nav.invoke('updateBubbleMic', {
        'active': active,
        if (lastCmd != null) 'lastCmd': lastCmd,
      });

  // ---------------------------------------------------------------------------
  // Traitement d'une commande vocale
  // ---------------------------------------------------------------------------

  Future<void> _handleSpeech(String rawText) async {
    // Évite le traitement concurrent de deux commandes
    if (_processing) return;
    _processing = true;

    try {
      // Normalisation phonétique puis corrections apprises
      final normalized = _learning.applyCorrections(
        PhoneticNormalizer.normalize(rawText),
      );
      debugPrint('[NavVocale] STT: "$rawText" → "$normalized"');

      // Tier 1 — parseur local (sur le texte normalisé)
      final cmd = CommandParser.parse(normalized);
      // Expose le texte original pour l'affichage UI
      _commandCtrl.add(VoiceCommand(
        rawText: rawText,
        type: cmd.type,
        parameter: cmd.parameter,
      ));

      if (!_voice.isMicEnabled) {
        if (cmd.type == CommandType.micOn) {
          unmuteMic();
          await _tts.speak('Micro activé.');
        } else if (cmd.type == CommandType.micOff) {
          await _tts.speak('Le micro est déjà en veille.');
        } else if (cmd.type == CommandType.stop) {
          await stop();
        } else {
          _emit('Micro en veille — en attente de "activer le micro".');
        }
        return;
      }

      if (cmd.type != CommandType.unknown) {
        _emit('Tier 1 : ${cmd.type.name}');
        final action = await _executeKnown(cmd);
        if (action != null) {
          _actionCtrl.add(action);
          if (action.isSuccess) {
            await _learning.recordSuccess(normalized, cmd.type.name);
          } else {
            _lastFailedText = rawText;
            await _learning.recordFailure(normalized);
            if (action.message != null) await _tts.speak(action.message!);
          }
        }
      } else {
        // Tier 2 — résolution intelligente sur l'arbre UI
        _emit('Tier 2 : analyse de l\'écran…');
        final nodes = await _nav.getScreenNodes();
        final resolution = _smart.resolve(normalized, nodes);

        if (resolution.action != SmartAction.none && resolution.confidence > 0.2) {
          _emit('Tier 2 (${(resolution.confidence * 100).round()}%) : '
              '${resolution.action.name} → "${resolution.node?.label ?? ''}"');
          final action = await _executeSmartResolution(resolution);
          _actionCtrl.add(action);
          if (action.isSuccess) {
            await _learning.recordSuccess(normalized, 'tier2_${resolution.action.name}');
          } else {
            _lastFailedText = rawText;
            await _learning.recordFailure(normalized);
          }
        } else {
          // Tier 3 — IA (si activée)
          if (_ai.isEnabled) {
            _emit('Tier 3 : envoi à l\'IA…');
            final aiRes = await _ai.resolve(normalized, nodes);
            if (aiRes.actionType != 'none') {
              _emit('Tier 3 : ${aiRes.actionType} → "${aiRes.target ?? ''}"');
              await _executeAiResolution(aiRes, nodes);
            } else if (aiRes.speak != null) {
              await _tts.speak(aiRes.speak!);
            } else {
              _lastFailedText = rawText;
              await _learning.recordFailure(normalized);
              _emit('Commande non reconnue : "$normalized"');
            }
          } else {
            _lastFailedText = rawText;
            await _learning.recordFailure(normalized);
            _emit('Non reconnu — activez l\'IA pour les commandes complexes');
          }
        }
      }

      // Reprend l'écoute
      if (_running && _voice.isMicEnabled) {
        await _voice.startListening();
      }
    } finally {
      _processing = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Exécution Tier 1 (commandes connues)
  // ---------------------------------------------------------------------------

  Future<NavigationAction?> _executeKnown(VoiceCommand cmd) async {
    switch (cmd.type) {
      case CommandType.home:         return _nav.performHome();
      case CommandType.back:         return _nav.performBack();
      case CommandType.recents:      return _nav.performRecents();
      case CommandType.notifications:return _nav.openNotifications();
      case CommandType.closeApp:     return _nav.closeCurrentApp();
      case CommandType.openApp:
        if (cmd.parameter != null)   return _nav.openApp(cmd.parameter!);
        return NavigationAction.failure('Nom d\'application manquant');

      case CommandType.scrollDown:   return _nav.scrollDown();
      case CommandType.scrollUp:     return _nav.scrollUp();
      case CommandType.swipeLeft:    return _nav.swipeLeft();
      case CommandType.swipeRight:   return _nav.swipeRight();
      case CommandType.tap:          return _nav.tap(targetDescription: cmd.parameter);
      case CommandType.longPress:    return _nav.longPress(targetDescription: cmd.parameter);

      // Dictée
      case CommandType.dictate:
        if (cmd.parameter != null)   return _nav.injectText(cmd.parameter!);
        return NavigationAction.failure('Texte à dicter manquant');
      case CommandType.submitText:   return _nav.submitText();
      case CommandType.clearText:    return _nav.clearText();
      case CommandType.deleteWord:   return _nav.deleteLastWord();

      // Lecture
      case CommandType.readScreen: {
        final t = await _nav.readScreenText();
        await _tts.speak(t);
        return NavigationAction.success;
      }
      case CommandType.readFocused: {
        final t = await _nav.readFocusedText();
        await _tts.speak(t.isEmpty ? 'Rien à lire ici.' : t);
        return NavigationAction.success;
      }
      case CommandType.readNotifications: {
        final t = await _nav.readNotificationsText();
        await _tts.speak(t);
        return NavigationAction.success;
      }
      case CommandType.readClipboard: {
        await _tts.speak('Lecture du presse-papiers non disponible dans cette version.');
        return NavigationAction.success;
      }

      // TTS contrôle
      case CommandType.stopReading:  await _tts.stop();   return null;
      case CommandType.readFaster:   await _tts.faster(); return null;
      case CommandType.readSlower:   await _tts.slower(); return null;
      case CommandType.readLouder:   await _tts.louder(); return null;
      case CommandType.readQuieter:  await _tts.quieter();return null;

      // Micro / SDK
      case CommandType.micOff:  muteMic();  return null;
      case CommandType.micOn:   unmuteMic();return null;
      case CommandType.stop:    await stop();return null;

      case CommandType.unknown: return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Exécution Tier 2 (résolution intelligente locale)
  // ---------------------------------------------------------------------------

  Future<NavigationAction> _executeSmartResolution(SmartResolution r) async {
    final node = r.node;
    switch (r.action) {
      case SmartAction.tap:
        if (node != null) return _nav.tap(targetDescription: node.label);
        return NavigationAction.failure('Aucune cible trouvée');
      case SmartAction.longPress:
        if (node != null) return _nav.longPress(targetDescription: node.label);
        return NavigationAction.failure('Aucune cible trouvée');
      case SmartAction.type:
        if (node != null) await _nav.tap(targetDescription: node.label);
        if (r.textToType != null) return _nav.injectText(r.textToType!);
        return NavigationAction.failure('Texte manquant');
      case SmartAction.scrollDown:  return _nav.scrollDown();
      case SmartAction.scrollUp:    return _nav.scrollUp();
      case SmartAction.none:
        return NavigationAction.failure('Aucune action trouvée');
    }
  }

  // ---------------------------------------------------------------------------
  // Exécution Tier 3 (IA)
  // ---------------------------------------------------------------------------

  Future<void> _executeAiResolution(AiResolution r, List nodes) async {
    switch (r.actionType) {
      case 'tap':
        if (r.target != null) await _nav.tap(targetDescription: r.target);
      case 'type':
        if (r.target != null) await _nav.tap(targetDescription: r.target);
        if (r.text != null)   await _nav.injectText(r.text!);
      case 'scroll_down':  await _nav.scrollDown();
      case 'scroll_up':    await _nav.scrollUp();
      case 'back':         await _nav.performBack();
      case 'home':         await _nav.performHome();
    }
    if (r.speak != null) await _tts.speak(r.speak!);
  }

  void _emit(String msg) {
    debugPrint('[NavVocale] $msg');
    _statusCtrl.add(msg);
  }

  // ---------------------------------------------------------------------------
  // Accès direct à la lecture TTS
  // ---------------------------------------------------------------------------

  Future<void> speak(String text) => _tts.speak(text);
  Future<void> stopSpeaking()     => _tts.stop();

  Future<bool> isAccessibilityEnabled()  => _nav.isAccessibilityEnabled();
  Future<void> openAccessibilitySettings() => _nav.openAccessibilitySettings();

  void dispose() {
    stop();
    _voice.dispose();
    _tts.dispose();
    _commandCtrl.close();
    _actionCtrl.close();
    _statusCtrl.close();
  }
}
