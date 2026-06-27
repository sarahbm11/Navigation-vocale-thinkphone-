enum CommandType {
  // Navigation système
  home,
  back,
  recents,
  notifications,
  openApp,
  closeApp,

  // Navigation dans l'appli courante
  scrollDown,
  scrollUp,
  swipeLeft,
  swipeRight,
  tap,
  longPress,

  // Dictée de texte
  dictate,       // "Écrire [texte]"
  submitText,    // "Envoyer" / "Valider" / appuie Entrée
  clearText,     // "Effacer" / "Supprimer tout"
  deleteWord,    // "Supprimer le mot"

  // Lecture à voix haute
  readScreen,        // "Lis l'écran"
  readFocused,       // "Lis ça" / "Qu'est-ce qu'il y a ici"
  readNotifications, // "Lis mes notifications"
  readClipboard,     // "Lis le presse-papiers"
  stopReading,       // "Arrête de lire" / "Silence"

  // Contrôle TTS
  readFaster,  // "Plus vite"
  readSlower,  // "Plus lentement"
  readLouder,  // "Plus fort"
  readQuieter, // "Moins fort"

  // Contrôle du micro / SDK
  micOn,
  micOff,
  stop,

  // Non reconnu
  unknown,
}

class VoiceCommand {
  final CommandType type;

  /// Paramètre optionnel (texte à dicter, nom d'appli, cible d'un tap…)
  final String? parameter;

  /// Texte brut reconnu par le moteur vocal
  final String rawText;

  const VoiceCommand({
    required this.type,
    required this.rawText,
    this.parameter,
  });

  @override
  String toString() => 'VoiceCommand(type: $type, param: $parameter, raw: "$rawText")';
}
