import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persiste et applique l'apprentissage des commandes vocales.
/// Toutes les données restent sur l'appareil (SharedPreferences).
class CommandLearningService {
  static const _kCorrections = 'nv_corrections'; // Map<String, String>
  static const _kAliases     = 'nv_aliases';     // Map<String, String>
  static const _kSuccesses   = 'nv_successes';   // Map<String, int>
  static const _kFailures    = 'nv_failures';    // Map<String, int>
  static const _kHistory     = 'nv_history';     // List<Map> max 500

  static const _maxHistory = 500;

  SharedPreferences? _prefs;

  Map<String, String> _corrections = {};
  Map<String, String> _aliases     = {};
  Map<String, int>    _successes   = {};
  Map<String, int>    _failures    = {};
  final List<Map<String, dynamic>> _history = [];

  bool get isReady => _prefs != null;

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _corrections = _loadMap(_kCorrections);
      _aliases     = _loadMap(_kAliases);
      _successes   = _loadIntMap(_kSuccesses);
      _failures    = _loadIntMap(_kFailures);

      final rawHistory = _prefs!.getString(_kHistory);
      if (rawHistory != null) {
        final list = jsonDecode(rawHistory) as List;
        _history.addAll(list.cast<Map<String, dynamic>>());
      }

      debugPrint('[NavVocale] Learning: ${_corrections.length} corrections, '
          '${_aliases.length} alias, ${_history.length} events');
    } catch (e) {
      debugPrint('[NavVocale] Learning init erreur: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Application en temps réel
  // ---------------------------------------------------------------------------

  /// Remplace les tokens connus dans le texte par leur correction apprise.
  String applyCorrections(String text) {
    var t = text;
    for (final entry in _corrections.entries) {
      t = t.replaceAll(entry.key, entry.value);
    }
    return t;
  }

  /// Retourne le vrai nom d'app si un alias est connu, sinon null.
  String? getAppAlias(String spokenName) =>
      _aliases[spokenName.toLowerCase().trim()];

  // ---------------------------------------------------------------------------
  // Enregistrement des résultats
  // ---------------------------------------------------------------------------

  /// À appeler quand une commande a été exécutée avec succès.
  Future<void> recordSuccess(String rawText, String commandType) async {
    _successes[commandType] = (_successes[commandType] ?? 0) + 1;
    _addHistory('success', rawText, commandType);
    await _persist();
  }

  /// À appeler quand la commande n'a pas été reconnue.
  Future<void> recordFailure(String rawText) async {
    final key = rawText.toLowerCase().trim();
    _failures[key] = (_failures[key] ?? 0) + 1;
    _addHistory('failure', rawText, null);
    await _persist();
  }

  // ---------------------------------------------------------------------------
  // Apprentissage explicite (correction de l'utilisateur)
  // ---------------------------------------------------------------------------

  /// Apprend que [wrongText] doit être interprété comme [correctText].
  /// Ex : "chronique" → "chrome"
  Future<void> learnCorrection(String wrongText, String correctText) async {
    final from = wrongText.toLowerCase().trim();
    final to   = correctText.toLowerCase().trim();
    if (from.isEmpty || to.isEmpty || from == to) return;
    _corrections[from] = to;
    _addHistory('learn_correction', from, to);
    await _persist();
    debugPrint('[NavVocale] Correction apprise: "$from" → "$to"');
  }

  /// Apprend qu'un nom prononcé correspond à un nom d'app réel.
  /// Ex : "kro" → "chrome"
  Future<void> learnAppAlias(String spokenName, String realAppName) async {
    final from = spokenName.toLowerCase().trim();
    final to   = realAppName.trim();
    if (from.isEmpty || to.isEmpty) return;
    _aliases[from] = to;
    _addHistory('learn_alias', from, to);
    await _persist();
    debugPrint('[NavVocale] Alias appris: "$from" → "$to"');
  }

  // ---------------------------------------------------------------------------
  // Statistiques (pour le panneau diagnostic)
  // ---------------------------------------------------------------------------

  Map<String, dynamic> getStats() {
    final totalOk   = _successes.values.fold<int>(0, (a, b) => a + b);
    final totalFail = _failures.values.fold<int>(0, (a, b) => a + b);
    final total = totalOk + totalFail;

    // Top 5 commandes réussies
    final topCmds = (_successes.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(5)
        .map((e) => {'cmd': e.key, 'count': e.value})
        .toList();

    // Top 5 phrases qui échouent
    final topFails = (_failures.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(5)
        .map((e) => {'text': e.key, 'count': e.value})
        .toList();

    return {
      'total': total,
      'successes': totalOk,
      'failures': totalFail,
      'rate': total > 0 ? (totalOk / total * 100).round() : 0,
      'corrections': _corrections.length,
      'aliases': _aliases.length,
      'historySize': _history.length,
      'topCommands': topCmds,
      'topFailures': topFails,
    };
  }

  /// Efface toutes les données apprises (reset complet).
  Future<void> reset() async {
    _corrections.clear();
    _aliases.clear();
    _successes.clear();
    _failures.clear();
    _history.clear();
    await _persist();
    debugPrint('[NavVocale] Learning réinitialisé');
  }

  // ---------------------------------------------------------------------------
  // Persistance interne
  // ---------------------------------------------------------------------------

  Future<void> _persist() async {
    if (_prefs == null) return;
    try {
      await Future.wait([
        _prefs!.setString(_kCorrections, jsonEncode(_corrections)),
        _prefs!.setString(_kAliases,     jsonEncode(_aliases)),
        _prefs!.setString(_kSuccesses,   jsonEncode(_successes)),
        _prefs!.setString(_kFailures,    jsonEncode(_failures)),
        _prefs!.setString(_kHistory,     jsonEncode(_history)),
      ]);
    } catch (e) {
      debugPrint('[NavVocale] Learning persist erreur: $e');
    }
  }

  void _addHistory(String event, String input, String? output) {
    _history.add({
      'e': event,
      'i': input,
      if (output != null) 'o': output,
      't': DateTime.now().millisecondsSinceEpoch,
    });
    // Garde les 500 derniers
    if (_history.length > _maxHistory) {
      _history.removeRange(0, _history.length - _maxHistory);
    }
  }

  Map<String, String> _loadMap(String key) {
    final raw = _prefs!.getString(key);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map).cast<String, String>();
    } catch (_) { return {}; }
  }

  Map<String, int> _loadIntMap(String key) {
    final raw = _prefs!.getString(key);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map).map((k, v) => MapEntry(k as String, v as int));
    } catch (_) { return {}; }
  }
}
