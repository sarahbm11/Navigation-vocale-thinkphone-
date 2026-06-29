import 'dart:async';
import 'package:flutter/material.dart';
import '../navigation_vocale_sdk.dart';
import '../models/voice_command.dart';
import '../ui/nav_theme.dart';

/// Overlay draggable compact (56px) affiché par-dessus toute l'application.
/// Pulse jaune quand le micro est actif, rouge quand muté.
class VoiceNavOverlay extends StatefulWidget {
  final NavigationVocaleSDK sdk;

  const VoiceNavOverlay({super.key, required this.sdk});

  @override
  State<VoiceNavOverlay> createState() => _VoiceNavOverlayState();
}

class _VoiceNavOverlayState extends State<VoiceNavOverlay>
    with SingleTickerProviderStateMixin {
  Offset _position = const Offset(20, 120);
  bool _micOn = true;
  String _lastCommand = '';
  StreamSubscription<VoiceCommand>? _sub;
  late final AnimationController _pulse;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _micOn = widget.sdk.isMicEnabled;
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    if (_micOn) _pulse.repeat(reverse: true);

    _sub = widget.sdk.onCommand.listen((cmd) {
      if (!mounted) return;
      setState(() => _lastCommand = _commandLabel(cmd));
    });
  }

  void _toggleMic() {
    setState(() {
      _micOn = !_micOn;
      if (_micOn) {
        widget.sdk.unmuteMic();
        _pulse.repeat(reverse: true);
      } else {
        widget.sdk.muteMic();
        _pulse.stop();
        _pulse.reset();
      }
    });
  }

  String _commandLabel(VoiceCommand cmd) {
    if (cmd.type == CommandType.unknown) return '"${cmd.rawText}"';
    final param = cmd.parameter != null ? ' · ${cmd.parameter}' : '';
    return '${cmd.type.name}$param';
  }

  @override
  Widget build(BuildContext context) {
    final color = _micOn ? NavColors.primary : NavColors.danger;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (d) => setState(() => _position += d.delta),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, child) => Transform.scale(
                scale: _micOn ? _pulseAnim.value : 1.0,
                child: child,
              ),
              child: GestureDetector(
                onTap: _toggleMic,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.15),
                    border: Border.all(color: color, width: 2),
                    boxShadow: [
                      if (_micOn)
                        BoxShadow(
                          color: NavColors.primary.withOpacity(0.35),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: Icon(
                    _micOn ? Icons.mic : Icons.mic_off,
                    color: color,
                    size: 24,
                  ),
                ),
              ),
            ),
            if (_lastCommand.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(maxWidth: 140),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: NavColors.surface.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: NavColors.border),
                ),
                child: Text(
                  _lastCommand,
                  style: NavTheme.caption(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
    _sub?.cancel();
    _pulse.dispose();
    super.dispose();
  }
}
