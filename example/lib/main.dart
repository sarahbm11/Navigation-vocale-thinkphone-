import 'package:flutter/material.dart';
import 'package:navigation_vocale/navigation_vocale.dart';

void main() => runApp(const NavVocaleApp());

class NavVocaleApp extends StatelessWidget {
  const NavVocaleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Navigation Vocale',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF1DB954),
          surface: const Color(0xFF111111),
        ),
        scaffoldBackgroundColor: const Color(0xFF111111),
      ),
      home: const NavVocalePage(),
    );
  }
}

class NavVocalePage extends StatefulWidget {
  const NavVocalePage({super.key});

  @override
  State<NavVocalePage> createState() => _NavVocalePageState();
}

class _NavVocalePageState extends State<NavVocalePage> {
  final _sdk = NavigationVocaleSDK();
  final List<_LogEntry> _log = [];

  bool _ready = false;
  bool _accessOk = false;
  bool _micOn = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final ok  = await _sdk.initialize();
    final acc = await _sdk.isAccessibilityEnabled();

    _sdk.onCommand.listen((cmd) {
      if (!mounted) return;
      setState(() => _log.insert(0, _LogEntry(
        icon: '🎙',
        text: '"${cmd.rawText}"',
        sub: cmd.type != CommandType.unknown ? cmd.type.name : null,
        color: Colors.white70,
      )));
      if (_log.length > 50) _log.removeLast();
    });

    _sdk.onStatus.listen((msg) {
      if (!mounted) return;
      setState(() => _log.insert(0, _LogEntry(
        icon: '⚙',
        text: msg,
        color: const Color(0xFF1DB954),
      )));
      if (_log.length > 50) _log.removeLast();
    });

    _sdk.onAction.listen((action) {
      if (!mounted || action.isSuccess) return;
      setState(() => _log.insert(0, _LogEntry(
        icon: '⚠',
        text: action.message ?? 'Erreur',
        color: Colors.orangeAccent,
      )));
    });

    setState(() {
      _ready = ok;
      _accessOk = acc;
      _micOn = true;
    });

    if (ok) await _sdk.start();
    if (!acc) await _sdk.speak('Veuillez activer le service d\'accessibilité pour commencer.');
  }

  void _toggleMic() {
    setState(() => _micOn = !_micOn);
    _micOn ? _sdk.unmuteMic() : _sdk.muteMic();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _Header(ready: _ready, micOn: _micOn, onMicTap: _toggleMic),
                if (!_accessOk)
                  _AccessibilityBanner(onTap: () async {
                    await _sdk.openAccessibilitySettings();
                  }),
                _CommandsCard(),
                _AiCard(sdk: _sdk),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Journal', style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ),
                ),
                Expanded(
                  child: _log.isEmpty
                      ? const Center(
                          child: Text(
                            'Parlez pour naviguer…',
                            style: TextStyle(color: Colors.white24, fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _log.length,
                          itemBuilder: (_, i) => _LogTile(entry: _log[i]),
                        ),
                ),
              ],
            ),
          ),

          // Bouton micro flottant
          Positioned(
            right: 20,
            bottom: 40,
            child: GestureDetector(
              onTap: _toggleMic,
              child: _MicFab(active: _micOn),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sdk.dispose();
    super.dispose();
  }
}

// ─── Widgets ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool ready;
  final bool micOn;
  final VoidCallback onMicTap;

  const _Header({required this.ready, required this.micOn, required this.onMicTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Navigation Vocale',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: (ready && micOn)
                      ? const Color(0xFF1DB954).withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (ready && micOn) ? const Color(0xFF1DB954) : Colors.red,
                  ),
                ),
                child: Text(
                  (ready && micOn) ? '● À l\'écoute' : micOn ? '● Initialisation…' : '● Micro coupé',
                  style: TextStyle(
                    fontSize: 11,
                    color: (ready && micOn) ? const Color(0xFF1DB954) : Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccessibilityBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _AccessibilityBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Appuyez ici pour activer le service d\'accessibilité → indispensable pour naviguer.',
                style: TextStyle(color: Colors.orange, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommandsCard extends StatelessWidget {
  const _CommandsCard();

  @override
  Widget build(BuildContext context) {
    const cmds = [
      ('🏠', 'Accueil'),
      ('⬅', 'Retour'),
      ('📱', 'Ouvrir [app]'),
      ('✍', 'Écrire [texte]'),
      ('📤', 'Envoyer'),
      ('🔊', 'Lis l\'écran'),
      ('🔇', 'Arrête de lire'),
      ('⬇', 'Défiler en bas'),
      ('👆', 'Appuie sur [X]'),
      ('🔇', 'Micro off / on'),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: cmds.map((c) => _Chip(icon: c.$1, label: c.$2)).toList(),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String icon;
  final String label;
  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Text('$icon $label', style: const TextStyle(fontSize: 12, color: Colors.white70)),
    );
  }
}

class _AiCard extends StatefulWidget {
  final NavigationVocaleSDK sdk;
  const _AiCard({required this.sdk});

  @override
  State<_AiCard> createState() => _AiCardState();
}

class _AiCardState extends State<_AiCard> {
  bool _expanded = false;
  final _keyCtrl = TextEditingController();
  bool _enabled = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _enabled
              ? const Color(0xFF1DB954).withOpacity(0.08)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _enabled ? const Color(0xFF1DB954).withOpacity(0.4) : Colors.white12,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🤖', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'IA — commandes libres (optionnel)',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white38, size: 18),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 10),
              const Text(
                'Activez l\'IA pour comprendre TOUTE commande.\n'
                'Seuls les labels de boutons visibles + votre commande sont envoyés.\n'
                'Jamais de données privées.',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _keyCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: 'Clé API Anthropic (sk-ant-…)',
                  hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  if (!_enabled && _keyCtrl.text.isNotEmpty) {
                    widget.sdk.enableAi(_keyCtrl.text.trim());
                    setState(() => _enabled = true);
                  } else if (_enabled) {
                    widget.sdk.disableAi();
                    setState(() => _enabled = false);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _enabled ? Colors.red.withOpacity(0.2) : const Color(0xFF1DB954).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _enabled ? Colors.red : const Color(0xFF1DB954)),
                  ),
                  child: Text(
                    _enabled ? 'Désactiver l\'IA' : 'Activer l\'IA',
                    style: TextStyle(
                      color: _enabled ? Colors.redAccent : const Color(0xFF1DB954),
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }
}

class _MicFab extends StatefulWidget {
  final bool active;
  const _MicFab({required this.active});

  @override
  State<_MicFab> createState() => _MicFabState();
}

class _MicFabState extends State<_MicFab> with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? const Color(0xFF1DB954) : Colors.red;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) {
        final scale = widget.active ? (1.0 + _pulse.value * 0.1) : 1.0;
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 16, spreadRadius: 2)],
        ),
        child: Icon(
          widget.active ? Icons.mic : Icons.mic_off,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }
}

class _LogEntry {
  final String icon;
  final String text;
  final String? sub;
  final Color color;
  const _LogEntry({required this.icon, required this.text, this.sub, required this.color});
}

class _LogTile extends StatelessWidget {
  final _LogEntry entry;
  const _LogTile({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.icon, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.text, style: TextStyle(color: entry.color, fontSize: 13)),
                if (entry.sub != null)
                  Text(entry.sub!, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
