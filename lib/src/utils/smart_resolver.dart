import '../models/screen_node.dart';

/// Résultat d'une résolution intelligente de commande.
class SmartResolution {
  final ScreenNode? node;
  final SmartAction action;
  final String? textToType;
  final double confidence; // 0.0 – 1.0

  const SmartResolution({
    this.node,
    required this.action,
    this.textToType,
    required this.confidence,
  });
}

enum SmartAction { tap, longPress, type, scrollDown, scrollUp, none }

/// Tier 2 — Résolution de commandes inconnues par analyse sémantique locale.
///
/// Prend l'arbre UI de l'écran et la commande brute, retourne l'action la plus
/// probable sans aucun appel réseau.
class SmartResolver {
  // Mots qui signalent une intention de tap/clic
  static const _tapIntents = [
    'appuie', 'appuyer', 'clique', 'cliquer', 'sélectionner', 'choisir',
    'ouvrir', 'fermer', 'tap', 'press', 'click', 'select', 'choose', 'open',
    'activer', 'activate', 'valider', 'confirmer', 'accepter', 'refuser',
    'annuler', 'cancel', 'ok', 'oui', 'non', 'yes', 'no', 'submit', 'send',
    'envoyer', 'partager', 'share', 'supprimer', 'delete', 'modifier', 'edit',
  ];

  // Mots qui signalent une intention d'écriture
  static const _typeIntents = [
    'écrire', 'écris', 'tape', 'taper', 'saisir', 'entrer', 'noter',
    'write', 'type', 'enter', 'input', 'rédiger', 'composer',
  ];

  // Mots de navigation de scroll
  static const _scrollDownIntents = [
    'bas', 'descendre', 'défiler', 'scroll', 'down', 'suite', 'plus bas',
    'continue', 'continuer',
  ];
  static const _scrollUpIntents = [
    'haut', 'monter', 'remonter', 'up', 'plus haut', 'retour en haut',
  ];

  SmartResolution resolve(String command, List<ScreenNode> nodes) {
    final words = _tokenize(command);

    // Détecte l'intention principale
    final hasTapIntent = words.any(_tapIntents.contains);
    final hasTypeIntent = words.any(_typeIntents.contains);
    final hasScrollDown = words.any(_scrollDownIntents.contains);
    final hasScrollUp = words.any(_scrollUpIntents.contains);

    if (hasScrollDown) {
      return const SmartResolution(action: SmartAction.scrollDown, confidence: 0.8);
    }
    if (hasScrollUp) {
      return const SmartResolution(action: SmartAction.scrollUp, confidence: 0.8);
    }

    // Cherche le meilleur nœud correspondant aux mots de la commande
    ScreenNode? best;
    double bestScore = 0.0;

    for (final node in nodes) {
      if (!node.isClickable && !node.isEditable) continue;
      final score = _score(words, node, preferEditable: hasTypeIntent);
      if (score > bestScore) {
        bestScore = score;
        best = node;
      }
    }

    // Si on a trouvé un champ éditable et intention d'écriture
    if (best != null && best.isEditable && hasTypeIntent) {
      final typeWords = words
          .skipWhile((w) => _typeIntents.contains(w))
          .join(' ')
          .trim();
      return SmartResolution(
        node: best,
        action: SmartAction.type,
        textToType: typeWords.isNotEmpty ? typeWords : null,
        confidence: bestScore,
      );
    }

    // Sinon → tap sur le meilleur bouton/élément
    if (best != null && bestScore > 0.2) {
      return SmartResolution(
        node: best,
        action: SmartAction.tap,
        confidence: bestScore,
      );
    }

    // Dernier recours : si commande ressemble à un tap sans cible claire
    if (hasTapIntent && nodes.any((n) => n.isFocused && n.isClickable)) {
      final focused = nodes.firstWhere((n) => n.isFocused && n.isClickable);
      return SmartResolution(node: focused, action: SmartAction.tap, confidence: 0.4);
    }

    return const SmartResolution(action: SmartAction.none, confidence: 0.0);
  }

  double _score(List<String> commandWords, ScreenNode node, {required bool preferEditable}) {
    final nodeWords = _tokenize(node.label);
    if (nodeWords.isEmpty) return 0.0;

    // Overlap de mots entre commande et étiquette du nœud
    final overlap = commandWords.where((w) => nodeWords.contains(w)).length;
    double score = overlap / commandWords.length.clamp(1, 99);

    // Bonus pour correspondance exacte de sous-chaîne
    final commandLower = commandWords.join(' ');
    final labelLower = node.label.toLowerCase();
    if (labelLower.contains(commandLower)) score += 0.3;
    if (commandLower.contains(labelLower) && labelLower.length > 2) score += 0.2;

    // Bonus si l'élément est du bon type
    if (preferEditable && node.isEditable) score += 0.25;
    if (!preferEditable && node.isClickable) score += 0.1;

    // Bonus si l'élément est déjà focalisé
    if (node.isFocused) score += 0.1;

    return score.clamp(0.0, 1.0);
  }

  List<String> _tokenize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r"[^\w\s]"), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.length > 1)
      .toList();
}
