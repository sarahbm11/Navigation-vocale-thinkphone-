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
  final TextEditingController _textController = TextEditingController();

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

  String _liveText = '';
  String _commandFeedback = '';
  bool _bubbleActive = false;
  double _soundLevel = 0.0;

  StreamSubscription<VoiceCommand>? _cmdSub;
  StreamSubscription<String>? _statusSub;
  StreamSubscription<String>? _partialSub;
  StreamSubscription<NavigationAction>? _actionSub;
  StreamSubscription<double>? _soundSub;

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
      _cmdSub    = _sdk.onCommand.listen(_onCommand);
      _statusSub = _sdk.onStatus.listen(_onStatus);
      _partialSub = _sdk.onPartialResult.listen((t) {
        if (!mounted) return;
        if (t == '[no_french_locale]' || t == '[lang_not_supported]') {
          setState(() => _commandFeedback =
              '⚠ Pack français manquant.\n'
              'Paramètres → Langue → Reconnaissance vocale hors ligne → Français (Canada)');
          Future.delayed(const Duration(seconds: 12), () {
            if (mounted) setState(() => _commandFeedback = '');
          });
        } else {
          setState(() => _liveText = t);
        }
      });
      _actionSub = _sdk.onAction.listen((action) {
        if (mounted && !action.isSuccess && action.message != null) {
          setState(() => _commandFeedback = action.message!);
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) setState(() => _commandFeedback = '');
          });
        }
      });
      _soundSub = _sdk.onSoundLevel.listen((level) {
        if (mounted) setState(() => _soundLevel = level);
      });
      _listenersAttached = true;
    }

    if (ok) await _startListening();
  }

  Future<void> _startListening() async {
    await _sdk.start();
    if (mounted) {
      setState(() => _listening = true);
      if (_bubbleActive) {
        await _sdk.updateBubbleMic(active: true);
      }
    }
  }

  Future<void> _stopListening() async {
    await _sdk.stop();
    if (mounted) {
      setState(() => _listening = false);
      if (_bubbleActive) {
        await _sdk.updateBubbleMic(active: false);
      }
    }
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
      _commandFeedback = '';
    });
    if (_bubbleActive) {
      _sdk.updateBubbleMic(active: _listening, lastCmd: cmd.rawText);
    }
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

  Future<void> _toggleBubble() async {
    if (_bubbleActive) {
      await _sdk.stopFloatingBubble();
      if (mounted) setState(() => _bubbleActive = false);
    } else {
      final canDraw = await _sdk.canDrawOverlay();
      if (!canDraw) {
        await _sdk.requestOverlayPermission();
        return;
      }
      final started = await _sdk.startFloatingBubble();
      if (mounted && started) {
        setState(() => _bubbleActive = true);
        if (_listening) await _sdk.updateBubbleMic(active: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NavColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    backgroundColor: NavColors.background,
                    pinned: true,
                    title: Text('Navigation Vocale', style: NavTheme.title()),
                    centerTitle: false,
                    actions: [
                      // Bouton bulle flottante
                      IconButton(
                        icon: Icon(
                          _bubbleActive ? Icons.bubble_chart : Icons.bubble_chart_outlined,
                          color: _bubbleActive ? NavColors.primary : NavColors.textSecondary,
                        ),
                        tooltip: _bubbleActive ? 'Fermer la bulle' : 'Bulle flottante',
                        onPressed: _toggleBubble,
                      ),
                      IconButton(
                        icon: const Icon(Icons.bar_chart_outlined),
                        color: NavColors.textSecondary,
                        tooltip: 'Diagnostic',
                        onPressed: _showDiagnostic,
                      ),
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

                          // Status / texte reconnu live
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            style: NavTheme.body().copyWith(
                              color: _initFailed
                                  ? NavColors.danger
                                  : (_liveText.isNotEmpty
                                      ? NavColors.text
                                      : (_listening ? NavColors.primary : NavColors.textSecondary)),
                              fontWeight: _listening ? FontWeight.w600 : FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                            child: Text(
                              _initFailed
                                  ? 'Permission micro requise —\nappuyez sur le cercle pour autoriser'
                                  : (_liveText.isNotEmpty
                                      ? _liveText
                                      : (_sdkReady
                                          ? (_listening ? 'En écoute…' : 'Micro désactivé')
                                          : 'Initialisation…')),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Niveau micro en temps réel
                          if (_listening) ...[
                            const SizedBox(height: 8),
                            _SoundLevelBar(level: _soundLevel),
                          ],

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

                          // Feedback erreur commande
                          if (_commandFeedback.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: NavColors.danger.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: NavColors.danger.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: NavColors.danger, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _commandFeedback,
                                      style: NavTheme.body().copyWith(
                                        color: NavColors.danger,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => setState(() => _commandFeedback = ''),
                                    child: const Icon(Icons.close, color: NavColors.danger, size: 16),
                                  ),
                                ],
                              ),
                            ),
                          ],

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

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _CommandBar(
              controller: _textController,
              micActive: _listening,
              micEnabled: _sdkReady,
              onMicTap: _toggleMic,
              onSubmit: (text) async {
                setState(() => _commandFeedback = '');
                await _sdk.processTextCommand(text);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDiagnostic() {
    final stats = _sdk.getLearningStats();
    final locale = _sdk.currentLocale ?? 'inconnu';
    showModalBottomSheet(
      context: context,
      backgroundColor: NavColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: NavColors.textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Diagnostic', style: NavTheme.title().copyWith(fontSize: 16)),
            const SizedBox(height: 12),
            _DiagRow('Locale STT', locale),
            _DiagRow('Taux de succès', '${stats['rate']}% (${stats['successes']}/${stats['total']})'),
            _DiagRow('Corrections apprises', '${stats['corrections']}'),
            _DiagRow('Alias d\'apps', '${stats['aliases']}'),
            _DiagRow('Événements mémorisés', '${stats['historySize']}'),
            if ((stats['topFailures'] as List).isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Phrases non reconnues :', style: NavTheme.caption()),
              const SizedBox(height: 4),
              ...(stats['topFailures'] as List).map((f) =>
                Text('  • ${f['text']} (×${f['count']})',
                    style: NavTheme.body().copyWith(fontSize: 12, color: NavColors.danger))),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () async {
                  await _sdk.getLearningStats(); // force sync
                  Navigator.pop(context);
                },
                child: Text('Fermer', style: NavTheme.body().copyWith(color: NavColors.primary)),
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
    _partialSub?.cancel();
    _actionSub?.cancel();
    _soundSub?.cancel();
    _textController.dispose();
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
          color: NavColors.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: NavColors.danger.withValues(alpha: 0.4)),
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

class _CommandBar extends StatelessWidget {
  final TextEditingController controller;
  final bool micActive;
  final bool micEnabled;
  final VoidCallback onMicTap;
  final Future<void> Function(String) onSubmit;

  const _CommandBar({
    required this.controller,
    required this.micActive,
    required this.micEnabled,
    required this.onMicTap,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final micColor = micActive ? NavColors.primary : NavColors.textSecondary;
    return Container(
      color: NavColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Row(
        children: [
          // Bouton micro
          GestureDetector(
            onTap: micEnabled ? onMicTap : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: micColor.withValues(alpha: 0.12),
                border: Border.all(color: micColor, width: 1.5),
                boxShadow: micActive
                    ? [BoxShadow(color: NavColors.primary.withValues(alpha: 0.25), blurRadius: 10, spreadRadius: 2)]
                    : [],
              ),
              child: Icon(
                micActive ? Icons.mic : Icons.mic_off,
                color: micColor,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Champ texte
          Expanded(
            child: TextField(
              controller: controller,
              style: NavTheme.body().copyWith(fontSize: 14, color: NavColors.text),
              decoration: InputDecoration(
                hintText: 'Taper une commande…',
                hintStyle: NavTheme.body().copyWith(fontSize: 14, color: NavColors.textSecondary),
                filled: true,
                fillColor: NavColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (v) {
                final t = v.trim();
                if (t.isNotEmpty) onSubmit(t);
                controller.clear();
              },
            ),
          ),
          const SizedBox(width: 8),
          // Bouton envoyer
          GestureDetector(
            onTap: () {
              final t = controller.text.trim();
              if (t.isNotEmpty) {
                onSubmit(t);
                controller.clear();
              }
            },
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: NavColors.primary.withValues(alpha: 0.15),
                border: Border.all(color: NavColors.primary, width: 1.5),
              ),
              child: const Icon(Icons.arrow_upward_rounded, color: NavColors.primary, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets de support
// ─────────────────────────────────────────────────────────────────────────────

class _SoundLevelBar extends StatelessWidget {
  final double level; // 0.0 → 1.0
  const _SoundLevelBar({required this.level});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Niveau micro', style: NavTheme.caption()),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: level,
            minHeight: 6,
            backgroundColor: NavColors.surface,
            valueColor: AlwaysStoppedAnimation<Color>(
              level < 0.1
                  ? NavColors.danger
                  : level < 0.6
                      ? NavColors.primary
                      : NavColors.success,
            ),
          ),
        ),
        if (level < 0.05)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '⚠ Signal très faible — parle plus fort ou rapproche-toi',
              style: NavTheme.caption().copyWith(color: NavColors.danger, fontSize: 11),
            ),
          ),
      ],
    );
  }
}

class _DiagRow extends StatelessWidget {
  final String label;
  final String value;
  const _DiagRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: NavTheme.body().copyWith(fontSize: 13, color: NavColors.textSecondary)),
          Text(value, style: NavTheme.body().copyWith(fontSize: 13, color: NavColors.text)),
        ],
      ),
    );
  }
}
