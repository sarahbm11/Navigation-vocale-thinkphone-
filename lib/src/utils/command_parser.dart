import '../models/voice_command.dart';

/// Convertit le texte reconnu en [VoiceCommand].
/// Supporte le français et l'anglais.
/// Aucune donnée n'est transmise à l'extérieur.
class CommandParser {
  static VoiceCommand parse(String text) {
    final t = text.toLowerCase().trim();

    // --- Contrôle micro/SDK ---
    if (_matches(t, ['micro off', 'couper le micro', 'silence', 'mute', 'couper microphone'])) {
      return VoiceCommand(type: CommandType.micOff, rawText: text);
    }
    if (_matches(t, ['micro on', 'activer le micro', 'unmute', 'réactiver'])) {
      return VoiceCommand(type: CommandType.micOn, rawText: text);
    }
    if (_matches(t, ['arrêter', 'stop', 'quitter navigation vocale', 'désactiver'])) {
      return VoiceCommand(type: CommandType.stop, rawText: text);
    }

    // --- Navigation système ---
    if (_matches(t, ['accueil', 'maison', 'home', 'retour accueil'])) {
      return VoiceCommand(type: CommandType.home, rawText: text);
    }
    if (_matches(t, ['retour', 'back', 'précédent', 'revenir'])) {
      return VoiceCommand(type: CommandType.back, rawText: text);
    }
    if (_matches(t, ['applications récentes', 'récents', 'recents', 'multitâche', 'apps ouvertes'])) {
      return VoiceCommand(type: CommandType.recents, rawText: text);
    }
    if (_matches(t, ['notifications', 'volet de notifications', 'ouvrir notifications'])) {
      return VoiceCommand(type: CommandType.notifications, rawText: text);
    }
    if (_matches(t, ['fermer', 'close', 'fermer l\'application', 'fermer app'])) {
      return VoiceCommand(type: CommandType.closeApp, rawText: text);
    }

    // --- Ouvrir une application ---
    final openMatch = _extractParam(t, ['ouvrir ', 'open ', 'lancer ', 'démarre ']);
    if (openMatch != null) {
      return VoiceCommand(type: CommandType.openApp, rawText: text, parameter: openMatch);
    }

    // --- Défilement ---
    if (_matches(t, ['défiler vers le bas', 'scroller bas', 'scroll down', 'descendre', 'bas'])) {
      return VoiceCommand(type: CommandType.scrollDown, rawText: text);
    }
    if (_matches(t, ['défiler vers le haut', 'scroller haut', 'scroll up', 'monter', 'haut'])) {
      return VoiceCommand(type: CommandType.scrollUp, rawText: text);
    }
    if (_matches(t, ['glisser gauche', 'swipe left', 'à gauche'])) {
      return VoiceCommand(type: CommandType.swipeLeft, rawText: text);
    }
    if (_matches(t, ['glisser droite', 'swipe right', 'à droite'])) {
      return VoiceCommand(type: CommandType.swipeRight, rawText: text);
    }

    // --- Appuyer ---
    final tapMatch = _extractParam(t, ['appuyer sur ', 'appuie sur ', 'cliquer sur ', 'tap ', 'cliquer ']);
    if (tapMatch != null) {
      return VoiceCommand(type: CommandType.tap, rawText: text, parameter: tapMatch);
    }
    if (_matches(t, ['appuyer', 'appuie', 'cliquer', 'tap', 'sélectionner', 'select'])) {
      return VoiceCommand(type: CommandType.tap, rawText: text);
    }

    // --- Appui long ---
    if (_matches(t, ['appui long', 'maintenir', 'long press', 'hold'])) {
      return VoiceCommand(type: CommandType.longPress, rawText: text);
    }

    return VoiceCommand(type: CommandType.unknown, rawText: text);
  }

  static bool _matches(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));

  static String? _extractParam(String text, List<String> prefixes) {
    for (final prefix in prefixes) {
      if (text.contains(prefix)) {
        final param = text.split(prefix).last.trim();
        if (param.isNotEmpty) return param;
      }
    }
    return null;
  }
}
