import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/screen_node.dart';

/// Résultat de l'IA.
class AiResolution {
  final String actionType; // 'tap' | 'type' | 'scroll_down' | 'scroll_up' | 'back' | 'home' | 'none'
  final String? target;   // étiquette de l'élément à toucher
  final String? text;     // texte à saisir si action == 'type'
  final String? speak;    // texte à lire à voix haute (réponse informative)

  const AiResolution({
    required this.actionType,
    this.target,
    this.text,
    this.speak,
  });

  factory AiResolution.none() => const AiResolution(actionType: 'none');

  factory AiResolution.fromJson(Map<String, dynamic> j) => AiResolution(
        actionType: j['action'] as String? ?? 'none',
        target: j['target'] as String?,
        text: j['text'] as String?,
        speak: j['speak'] as String?,
      );
}

/// Tier 3 — Résolution par IA (Claude API).
///
/// DÉSACTIVÉ par défaut. L'utilisateur doit explicitement appeler [enable].
///
/// Ce qui est envoyé au serveur :
///   - La commande vocale de l'utilisateur
///   - Les étiquettes visibles des éléments cliquables de l'écran
///     (textes de boutons, libellés de champs — PAS le contenu des champs)
///
/// Ce qui N'EST PAS envoyé :
///   - Le contenu des champs de saisie
///   - Les messages privés ou données personnelles
///   - Aucun historique entre les sessions
class AiResolver {
  bool _enabled = false;
  String? _apiKey;

  bool get isEnabled => _enabled;

  void enable(String apiKey) {
    _enabled = true;
    _apiKey = apiKey;
  }

  void disable() {
    _enabled = false;
    _apiKey = null;
  }

  Future<AiResolution> resolve(String command, List<ScreenNode> nodes) async {
    if (!_enabled || _apiKey == null) return AiResolution.none();

    // On n'envoie que les étiquettes visibles (pas le contenu privé des champs)
    final elements = nodes
        .where((n) => n.isClickable || n.isEditable || n.isScrollable)
        .map((n) => {
              'label': n.label,
              'type': n.isEditable
                  ? 'input'
                  : n.isScrollable
                      ? 'scrollable'
                      : 'button',
            })
        .take(40) // limiter la taille du prompt
        .toList();

    final prompt = '''
Tu contrôles un téléphone Android par la voix pour un utilisateur sans mains.
L'utilisateur a dit : "$command"

Éléments UI visibles sur l'écran (étiquettes de boutons et champs uniquement) :
${jsonEncode(elements)}

Réponds UNIQUEMENT avec un JSON valide sur une seule ligne, sans explication :
{"action":"tap|type|scroll_down|scroll_up|back|home|none","target":"étiquette exacte ou null","text":"texte à saisir ou null","speak":"message à lire à voix haute ou null"}

Règles :
- "action":"tap" → clique sur l'élément dont l'étiquette est "target"
- "action":"type" → saisit "text" dans le champ "target" (ou le champ actif si target=null)
- "action":"scroll_down"/"scroll_up" → défile l'écran
- "action":"back"/"home" → navigation système
- "action":"none" + "speak":"..." → réponds vocalement si la commande est une question
- "target" doit correspondre EXACTEMENT à une étiquette de la liste ci-dessus
''';

    try {
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _apiKey!,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-haiku-4-5-20251001',
          'max_tokens': 256,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return AiResolution.none();

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final content = (body['content'] as List).first['text'] as String;

      // Extrait le JSON de la réponse
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(content);
      if (jsonMatch == null) return AiResolution.none();

      final parsed = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
      return AiResolution.fromJson(parsed);
    } catch (_) {
      return AiResolution.none();
    }
  }
}
