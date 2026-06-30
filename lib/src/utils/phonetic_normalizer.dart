/// Corrige les erreurs acoustiques fréquentes du STT français.
/// Toutes les substitutions sont deterministes et appliquées localement.
class PhoneticNormalizer {
  // Paires (erreur STT → texte corrigé). Ordre important : plus spécifique en premier.
  static const List<(String, String)> _corrections = [
    // ── Applications ────────────────────────────────────────────────────────
    ("what's app", "whatsapp"),
    ("watts app", "whatsapp"),
    ("what sapp", "whatsapp"),
    ("watsap", "whatsapp"),
    ("what app", "whatsapp"),
    ("you tube", "youtube"),
    ("you-tube", "youtube"),
    ("utube", "youtube"),
    ("face book", "facebook"),
    ("face-book", "facebook"),
    ("tick toc", "tiktok"),
    ("tic toc", "tiktok"),
    ("tick tock", "tiktok"),
    ("tik tok", "tiktok"),
    ("google chrome", "chrome"),
    ("chromé", "chrome"),
    ("chronique", "chrome"),
    ("krome", "chrome"),
    ("snap chat", "snapchat"),
    ("ins ta", "instagram"),
    ("insta gram", "instagram"),
    ("télé gramme", "telegram"),
    ("télé gram", "telegram"),
    ("spotify fi", "spotify"),
    ("net flix", "netflix"),
    ("amazon prime", "prime video"),

    // ── Commandes de navigation ──────────────────────────────────────────────
    ("page d'accueil", "accueil"),
    ("page accueil", "accueil"),
    ("retourne", "retour"),
    ("retourner", "retour"),
    ("go back", "retour"),
    ("revenir", "retour"),
    ("go home", "accueil"),
    ("tâches récentes", "récents"),
    ("tâche récente", "récents"),
    ("apps récentes", "récents"),

    // ── Verbes : formes conjuguées → impératif ───────────────────────────────
    ("ouvrir ", "ouvre "),
    ("ouvert ", "ouvre "),
    ("ouvrez ", "ouvre "),
    ("fermer ", "ferme "),
    ("fermé ", "ferme "),
    ("fermez ", "ferme "),
    ("envoyer ", "envoie "),
    ("envoyez ", "envoie "),
    ("écrire ", "écris "),
    ("écrit ", "écris "),
    ("écrivez ", "écris "),
    ("taper ", "tape "),
    ("tapez ", "tape "),
    ("appuyer ", "appuie "),
    ("appuyez ", "appuie "),
    ("appuis ", "appuie "),
    ("défiler ", "défile "),
    ("défilez ", "défile "),
    ("scroller ", "défile "),
    ("lancer ", "ouvre "),
    ("lancez ", "ouvre "),
    ("démarrer ", "ouvre "),
    ("démarrez ", "ouvre "),
    ("quitter ", "ferme "),
    ("quittez ", "ferme "),

    // ── Articles avant noms d'app (pour normalizeAppName) ───────────────────
    // (traités dans normalizeAppName, mais aussi ici pour le flux principal)
    ("ouvre le ", "ouvre "),
    ("ouvre la ", "ouvre "),
    ("ouvre les ", "ouvre "),
    ("ouvre l'", "ouvre "),
    ("ferme le ", "ferme "),
    ("ferme la ", "ferme "),
    ("ferme les ", "ferme "),
    ("ferme l'", "ferme "),

    // ── Micro / son ──────────────────────────────────────────────────────────
    ("micro of", "micro off"),
    ("micro au", "micro off"),   // "éteins le micro" → "micro off"
    ("son of", "son off"),
    ("coupe le son", "micro off"),
    ("active le micro", "micro on"),
    ("allume le micro", "micro on"),

    // ── Défilement ───────────────────────────────────────────────────────────
    ("scroll down", "défiler bas"),
    ("scroll up", "défiler haut"),
    ("défile en bas", "défiler bas"),
    ("défile vers le bas", "défiler bas"),
    ("défile en haut", "défiler haut"),
    ("défile vers le haut", "défiler haut"),

    // ── Dictée ───────────────────────────────────────────────────────────────
    ("écrire ", "écris "),
    ("tape le texte ", "écris "),
    ("saisi ", "écris "),
    ("saisir ", "écris "),

    // ── Faux positifs courants ───────────────────────────────────────────────
    ("ou vert", "ouvre"),     // "ou vert" → "ouvre"
    ("à verre", "ouvre"),
  ];

  /// Applique toutes les corrections phonétiques au texte normalisé en minuscules.
  static String normalize(String text) {
    var t = text.toLowerCase().trim();

    // Normalise les apostrophes typographiques → ASCII
    t = t.replaceAll('’', "'").replaceAll('‘', "'");

    // Applique les substitutions dans l'ordre déclaré
    for (final (from, to) in _corrections) {
      if (t.contains(from)) t = t.replaceAll(from, to);
    }

    // Supprime la ponctuation finale
    t = t.replaceAll(RegExp(r'[,.!?]+$'), '').trim();

    return t;
  }

  /// Nettoie un nom d'application : supprime les articles français, normalise.
  /// Ex : "l'application chrome" → "chrome"
  ///      "le jeu minecraft" → "minecraft"
  static String normalizeAppName(String name) {
    var t = name.toLowerCase().trim();

    // Supprime les apostrophes typographiques
    t = t.replaceAll('’', "'").replaceAll('‘', "'");

    // Supprime les articles + substantifs courants devant le nom
    t = t
        .replaceFirst(RegExp(r"^l'application\s+"), '')
        .replaceFirst(RegExp(r"^l'app\s+"), '')
        .replaceFirst(RegExp(r"^l'appli\s+"), '')
        .replaceFirst(RegExp(r"^le jeu\s+"), '')
        .replaceFirst(RegExp(r"^l[ea]s?\s+"), '')
        .replaceFirst(RegExp(r"^l'"), '')
        .trim();

    return t;
  }
}
