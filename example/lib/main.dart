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
      theme: ThemeData.dark(useMaterial3: true),
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
  final List<String> _log = [];

  bool _ready = false;
  bool _accessibilityOk = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final ok = await _sdk.initialize();
    final acc = await _sdk.isAccessibilityEnabled();

    _sdk.onCommand.listen((cmd) {
      if (!mounted) return;
      setState(() => _log.insert(0, '🎙 ${cmd.rawText}  →  ${cmd.type.name}'));
    });

    _sdk.onAction.listen((action) {
      if (!mounted) return;
      if (!action.isSuccess) {
        setState(() => _log.insert(0, '⚠️ ${action.message}'));
      }
    });

    setState(() {
      _ready = ok;
      _accessibilityOk = acc;
    });

    if (ok) await _sdk.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Navigation Vocale',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  _statusChip(),
                  const SizedBox(height: 20),
                  if (!_accessibilityOk) _accessibilityBanner(),
                  const SizedBox(height: 10),
                  const Text(
                    'Commandes disponibles',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  _commandList(),
                  const Divider(color: Colors.white12, height: 32),
                  const Text(
                    'Historique',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _log.isEmpty
                        ? const Center(
                            child: Text('Parlez pour naviguer…',
                                style: TextStyle(color: Colors.white38)),
                          )
                        : ListView.builder(
                            itemCount: _log.length,
                            itemBuilder: (_, i) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Text(_log[i],
                                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          // Overlay micro draggable
          VoiceNavOverlay(sdk: _sdk),
        ],
      ),
    );
  }

  Widget _statusChip() {
    final on = _ready && _sdk.isRunning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: on ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: on ? Colors.green : Colors.red, width: 1),
      ),
      child: Text(
        on ? '● Actif — parlez maintenant' : '● Inactif',
        style: TextStyle(color: on ? Colors.greenAccent : Colors.redAccent, fontSize: 12),
      ),
    );
  }

  Widget _accessibilityBanner() {
    return GestureDetector(
      onTap: _sdk.openAccessibilitySettings,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange, width: 1),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Service d\'accessibilité désactivé.\nAppuyez pour l\'activer dans les Paramètres.',
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _commandList() {
    const commands = [
      ('Accueil / Home', 'Retour à l\'écran d\'accueil'),
      ('Retour / Back', 'Page précédente'),
      ('Ouvrir [app]', 'Ex: "Ouvrir Caméra"'),
      ('Défiler vers le bas', 'Scroll vers le bas'),
      ('Défiler vers le haut', 'Scroll vers le haut'),
      ('Appuyer sur [élément]', 'Ex: "Appuyer sur OK"'),
      ('Micro off / Micro on', 'Couper/réactiver le micro'),
      ('Applications récentes', 'Afficher le multitâche'),
      ('Notifications', 'Ouvrir le volet de notifications'),
      ('Arrêter', 'Désactiver la navigation vocale'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: commands
          .map((c) => Tooltip(
                message: c.$2,
                child: Chip(
                  label: Text(c.$1, style: const TextStyle(fontSize: 11)),
                  backgroundColor: Colors.white10,
                  side: const BorderSide(color: Colors.white12),
                ),
              ))
          .toList(),
    );
  }

  @override
  void dispose() {
    _sdk.dispose();
    super.dispose();
  }
}
