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
  scrollLeft,
  scrollRight,
  tap,
  longPress,
  swipeLeft,
  swipeRight,

  // Contrôle du micro / SDK
  micOn,
  micOff,
  stop,

  // Non reconnu
  unknown,
}

class VoiceCommand {
  final CommandType type;

  /// Paramètre optionnel (ex. nom d'appli, cible d'un tap)
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
