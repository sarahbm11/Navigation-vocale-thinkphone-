import 'dart:async';
import 'package:flutter/material.dart';
import 'package:navigation_vocale/navigation_vocale.dart';
import 'package:navigation_vocale/src/ui/nav_theme.dart';
import 'package:navigation_vocale/src/ui/widgets/voice_ring_widget.dart';
import 'package:navigation_vocale/src/ui/widgets/waveform_widget.dart';
import 'package:navigation_vocale/src/ui/widgets/level_chips_widget.dart';
import 'package:navigation_vocale/src/ui/widgets/command_card_widget.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final NavigationVocaleSDK _sdk = NavigationVocaleSDK();

  bool _sdkReady = false;
  bool _listening = false;
  bool _accessibilityOk = false;
  bool _initFailed = false;
  bool _listenersAttached = false;

  String _lastCommandText = '';
  String _lastCommandLabel = '';
  int _lastCommandTier = 0;
  ActiveTier _activeTier = ActiveTier.none;

  final List<({String text, String label, int tier})> _log = [];

  StreamSubscription<VoiceCommand>? _cmdSub;
  StreamSubscription<String>? _statusSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final ok = await _sdk.initialize();
    final a11y = await _sdk.isAccessibilityEnabled();
    if (!mounted) return;
    setState(() {
      _sdkReady = ok;
      _initFailed = !ok;
      _accessibilityOk = a11y;
    });

    // N'attache les écouteurs qu'une seule fois (init peut être ré-essayé).
    if (!_listenersAttached) {
      _cmdSub = _sdk.onCommand.listen(_onCommand);
      _statusSub = _sdk.onStatus.listen(_onStatus);
      _listenersAttached = true;
    }

    if (ok) await _startListening();
  }

  Future<void> _startListening() async {
    await _sdk.start();
    if (mounted) setState(() => _listening = true);
  }

  Future<void> _stopListening() async {
    await _sdk.stop();
    if (mounted) setState(() => _listening = false);
  }

  void _onCommand(VoiceCommand cmd) {
    if (!mounted) return;
    final tier = cmd.type != CommandType.unknown ? 1 : 0;
    final label = tier == 1 ? 'Tier 1 · Local' : '';
    setState(() {
      _lastCommandText = cmd.rawText;
      _lastCommandLabel = label;
      _lastCommandTier = tier;
      _activeTier = tier == 1 ? ActiveTier.tier1 : ActiveTier.none;
      _log.insert(0, (text: cmd.rawText, label: label, tier: tier));
      if (_log.length > 50) _log.removeLast();
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _activeTier = ActiveTier.none);
    });
  }

  void _onStatus(String status) {
    if (!mounted) return;
    ActiveTier tier = ActiveTier.none;
    if (status.startsWith('Tier 1')) tier = ActiveTier.tier1;
    else if (status.startsWith('Tier 2')) tier = ActiveTier.tier2;
    else if (status.startsWith('Tier 3')) tier = ActiveTier.tier3;

    final cmdTier = tier == ActiveTier.tier2 ? 2 : tier == ActiveTier.tier3 ? 3 : _lastCommandTier;
    final cmdLabel = tier == ActiveTier.tier2
        ? 'Tier 2 · UI Tree'
        : tier == ActiveTier.tier3
            ? 'Tier 3 · Claude IA'
            : _lastCommandLabel;

    setState(() {
      _activeTier = tier;
      if (tier != ActiveTier.none) {
        _lastCommandTier = cmdTier;
        _lastCommandLabel = cmdLabel;
      }
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _activeTier = ActiveTier.none);
    });
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NavColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: NavColors.background,
                  pinned: true,
                  title: Text('Navigation Vocale', style: NavTheme.title()),
                  centerTitle: false,
                  actions: [
                    if (!_accessibilityOk)
                      IconButton(
                        icon: const Icon(Icons.accessibility_new, color: NavColors.danger),
                        tooltip: 'Activer l\'accessibilité',
                        onPressed: _sdk.openAccessibilitySettings,
                      ),
                    const SizedBox(width: 8),
                  ],
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 32),

                        if (!_accessibilityOk)
                          _AccessibilityBanner(onTap: _sdk.openAccessibilitySettings),

                        const SizedBox(height: 24),

                        // Central mic ring — tap pour (dé)activer, ou réessayer
                        // l'init si la permission micro a été refusée.
                        GestureDetector(
                          onTap: _sdkReady
                              ? _toggleMic
                              : (_initFailed ? _init : null),
                          child: VoiceRingWidget(
                            active: _listening,
                            size: 140,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Status text
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: NavTheme.body().copyWith(
                            color: _initFailed
                                ? NavColors.danger
                                : (_listening ? NavColors.primary : NavColors.textSecondary),
                            fontWeight: _listening ? FontWeight.w600 : FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                          child: Text(
                            _initFailed
                                ? 'Permission micro requise —\nappuyez sur le cercle pour autoriser'
                                : (_sdkReady
                                    ? (_listening ? 'Écoute en cours…' : 'Micro désactivé')
                                    : 'Initialisation…'),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Waveform
                        WaveformWidget(active: _listening, height: 48),

                        const SizedBox(height: 32),

                        // Tier chips
                        LevelChipsWidget(activeTier: _activeTier),

                        const SizedBox(height: 24),

                        // Last command card
                        CommandCardWidget(
                          text: _lastCommandText,
                          label: _lastCommandLabel,
                          tier: _lastCommandTier,
                        ),

                        const SizedBox(height: 32),

                        // Log
                        if (_log.isNotEmpty) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Historique', style: NavTheme.caption()),
                          ),
                          const SizedBox(height: 8),
                          ..._log.take(10).map((entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: CommandCardWidget(
                              text: entry.text,
                              label: entry.label,
                              tier: entry.tier,
                            ),
                          )),
                        ],

                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Floating mic toggle button
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Center(
                child: _MicToggleButton(
                  listening: _listening,
                  enabled: _sdkReady,
                  onTap: _toggleMic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cmdSub?.cancel();
    _statusSub?.cancel();
    _sdk.dispose();
    super.dispose();
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: NavColors.danger.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: NavColors.danger.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: NavColors.danger, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Service d\'accessibilité désactivé',
                    style: NavTheme.body().copyWith(color: NavColors.danger, fontSize: 13),
                  ),
                  Text(
                    'Appuie pour l\'activer dans les paramètres',
                    style: NavTheme.caption(),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: NavColors.danger, size: 14),
          ],
        ),
      ),
    );
  }
}

class _MicToggleButton extends StatelessWidget {
  final bool listening;
  final bool enabled;
  final VoidCallback onTap;

  const _MicToggleButton({
    required this.listening,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = listening ? NavColors.primary : NavColors.textSecondary;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.12),
          border: Border.all(color: color, width: 2),
          boxShadow: listening
              ? [BoxShadow(color: NavColors.primary.withOpacity(0.3), blurRadius: 20, spreadRadius: 4)]
              : [],
        ),
        child: Icon(
          listening ? Icons.mic : Icons.mic_off,
          color: color,
          size: 32,
        ),
      ),
    );
  }
}
