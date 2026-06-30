import '../models/voice_command.dart';

/// Convertit le texte reconnu en [VoiceCommand].
/// Supporte le français et l'anglais. Traitement 100 % local.
class CommandParser {
  static VoiceCommand parse(String text) {
    // Supprime les formules de politesse avant le matching
    final cleaned = text
        .toLowerCase()
        .trim()
        .replaceAll("s'il te plaît", '')
        .replaceAll("s'il vous plaît", '')
        .replaceAll('stp', '')
        .trim();
    final t = cleaned;

    // --- Lecture à voix haute (priorité haute — évite conflit avec "arrêter") ---
    if (_matches(t, ['arrête de lire', 'stop de lire', 'tais-toi', 'tais toi', 'stop reading', 'stop la lecture'])) {
      return VoiceCommand(type: CommandType.stopReading, rawText: text);
    }
    if (_matches(t, ['lis l\'écran', 'lire l\'écran', 'qu\'est-ce qu\'il y a sur l\'écran',
        'qu\'est-ce qui est écrit', 'read screen', 'read the screen', 'qu\'est-ce que ça dit',
        'lis ce qu\'il y a', 'lis tout', 'dis-moi ce qu\'il y a sur l\'écran'])) {
      return VoiceCommand(type: CommandType.readScreen, rawText: text);
    }
    if (_matches(t, ['lis ça', 'lis ceci', 'lis ce texte', 'lis le message', 'lis le contenu',
        'qu\'est-ce qu\'il y a ici', 'read this', 'read it', 'lis-moi ça', 'qu\'est-ce que c\'est'])) {
      return VoiceCommand(type: CommandType.readFocused, rawText: text);
    }
    if (_matches(t, ['lis mes notifications', 'lis les notifications', 'read notifications',
        'qu\'est-ce que j\'ai comme notification', 'mes notifications'])) {
      return VoiceCommand(type: CommandType.readNotifications, rawText: text);
    }
    if (_matches(t, ['lis le presse-papiers', 'lis le presse papiers', 'lis ce que j\'ai copié',
        'read clipboard', 'qu\'est-ce que j\'ai copié'])) {
      return VoiceCommand(type: CommandType.readClipboard, rawText: text);
    }

    // --- Contrôle vitesse/volume TTS ---
    if (_matches(t, ['plus vite', 'plus rapidement', 'accélère', 'faster', 'speed up'])) {
      return VoiceCommand(type: CommandType.readFaster, rawText: text);
    }
    if (_matches(t, ['plus lentement', 'plus lent', 'ralentis', 'slower', 'slow down'])) {
      return VoiceCommand(type: CommandType.readSlower, rawText: text);
    }
    if (_matches(t, ['plus fort', 'augmente le volume', 'louder', 'volume up'])) {
      return VoiceCommand(type: CommandType.readLouder, rawText: text);
    }
    if (_matches(t, ['moins fort', 'baisse le volume', 'quieter', 'volume down'])) {
      return VoiceCommand(type: CommandType.readQuieter, rawText: text);
    }

    // --- Contrôle micro/SDK ---
    if (_matches(t, ['micro off', 'couper le micro', 'mute', 'couper microphone', 'désactiver le micro'])) {
      return VoiceCommand(type: CommandType.micOff, rawText: text);
    }
    if (_matches(t, ['micro on', 'activer le micro', 'unmute', 'réactiver le micro', 'remettre le micro'])) {
      return VoiceCommand(type: CommandType.micOn, rawText: text);
    }
    if (_matches(t, ['quitter navigation vocale', 'désactiver navigation vocale', 'fermer navigation vocale'])) {
      return VoiceCommand(type: CommandType.stop, rawText: text);
    }

    // --- Dictée de texte ---
    final dictateMatch = _extractParam(t, [
      'écrire ', 'écris ', 'écrit ', 'tape ', 'taper ', 'saisir ', 'saisir le texte ',
      'write ', 'type ', 'dicter ', 'dictée ',
      'note ', 'rédige ', 'compose ',
    ]);
    if (dictateMatch != null) {
      return VoiceCommand(type: CommandType.dictate, rawText: text, parameter: dictateMatch);
    }

    if (_matches(t, ['envoyer', 'envoie', 'valider', 'valide', 'submit', 'send', 'confirmer', 'appuie entrée', 'entrée'])) {
      return VoiceCommand(type: CommandType.submitText, rawText: text);
    }
    if (_matches(t, ['effacer tout', 'supprimer tout', 'vider le champ', 'clear', 'tout effacer', 'tout supprimer'])) {
      return VoiceCommand(type: CommandType.clearText, rawText: text);
    }
    if (_matches(t, ['supprimer le mot', 'effacer le mot', 'delete word', 'supprimer dernier mot'])) {
      return VoiceCommand(type: CommandType.deleteWord, rawText: text);
    }

    // --- Navigation système ---
    if (_matches(t, [
      'accueil', 'maison', 'home', 'retour accueil', 'écran d\'accueil',
      'va à l\'accueil', 'revenir à l\'accueil', 'aller à l\'accueil', 'écran principal',
    ])) {
      return VoiceCommand(type: CommandType.home, rawText: text);
    }
    if (_matches(t, [
      'retour', 'back', 'précédent', 'revenir', 'page précédente',
      'revenir en arrière', 'go back', 'page d\'avant',
    ])) {
      return VoiceCommand(type: CommandType.back, rawText: text);
    }
    if (_matches(t, ['applications récentes', 'récents', 'recents', 'multitâche', 'apps ouvertes', 'changer d\'application'])) {
      return VoiceCommand(type: CommandType.recents, rawText: text);
    }
    if (_matches(t, ['notifications', 'volet de notifications', 'ouvrir notifications', 'ouvrir le volet'])) {
      return VoiceCommand(type: CommandType.notifications, rawText: text);
    }
    if (_matches(t, ['fermer', 'close', "fermer l'application", 'fermer app', 'quitter l\'application'])) {
      return VoiceCommand(type: CommandType.closeApp, rawText: text);
    }

    // --- Ouvrir une application ---
    // Préfixes longs en premier pour éviter de garder "l'application X" comme nom d'app.
    final openMatch = _extractParam(t, [
      "ouvrir l'application ", "ouvrir l'app ", "ouvrir l'appli ",
      'ouvrir l\'appli ', 'ouvrir le jeu ',
      "lancer l'application ", "lancer l'app ", "lancer l'appli ",
      "démarrer l'application ", "démarrer l'app ",
      "ouvre l'application ", "ouvre l'app ",
      'ouvrir ', 'ouvre ', 'open ', 'lancer ', 'lance ', 'démarre ', 'démarrer ',
    ]);
    if (openMatch != null) {
      return VoiceCommand(type: CommandType.openApp, rawText: text, parameter: openMatch.trim());
    }

    // --- Défilement ---
    if (_matches(t, ['défiler vers le bas', 'défiler en bas', 'scroller bas', 'scroll down', 'descendre', 'en bas'])) {
      return VoiceCommand(type: CommandType.scrollDown, rawText: text);
    }
    if (_matches(t, ['défiler vers le haut', 'défiler en haut', 'scroller haut', 'scroll up', 'monter', 'en haut'])) {
      return VoiceCommand(type: CommandType.scrollUp, rawText: text);
    }
    if (_matches(t, ['glisser gauche', 'swipe left', 'aller à gauche', 'page suivante à gauche'])) {
      return VoiceCommand(type: CommandType.swipeLeft, rawText: text);
    }
    if (_matches(t, ['glisser droite', 'swipe right', 'aller à droite', 'page suivante à droite'])) {
      return VoiceCommand(type: CommandType.swipeRight, rawText: text);
    }

    // --- Appuyer ---
    final tapMatch = _extractParam(t, [
      'appuyer sur ', 'appuie sur ', 'cliquer sur ', 'tap on ',
      'appuie ', 'clique sur ', 'touche ', 'clique ', 'presse ',
    ]);
    if (tapMatch != null) {
      return VoiceCommand(type: CommandType.tap, rawText: text, parameter: tapMatch);
    }
    if (_matches(t, ['appuyer', 'appuie', 'cliquer', 'tap', 'sélectionner', 'select', 'ok', 'confirmer'])) {
      return VoiceCommand(type: CommandType.tap, rawText: text);
    }

    // --- Appui long ---
    if (_matches(t, ['appui long', 'maintenir', 'long press', 'hold', 'tenir appuyé'])) {
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
