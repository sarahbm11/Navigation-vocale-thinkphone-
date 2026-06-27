import 'package:flutter/material.dart';
import '../navigation_vocale_sdk.dart';

/// Bouton flottant pour activer/couper le micro d'un seul appui.
class VoiceNavButton extends StatefulWidget {
  final NavigationVocaleSDK sdk;
  final Color activeColor;
  final Color mutedColor;

  const VoiceNavButton({
    super.key,
    required this.sdk,
    this.activeColor = const Color(0xFF1DB954),
    this.mutedColor = const Color(0xFFE53935),
  });

  @override
  State<VoiceNavButton> createState() => _VoiceNavButtonState();
}

class _VoiceNavButtonState extends State<VoiceNavButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late bool _micOn;

  @override
  void initState() {
    super.initState();
    _micOn = widget.sdk.isMicEnabled;
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  void _toggle() {
    setState(() {
      if (_micOn) {
        widget.sdk.muteMic();
        _micOn = false;
        _pulse.stop();
      } else {
        widget.sdk.unmuteMic();
        _micOn = true;
        _pulse.repeat(reverse: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = _micOn ? widget.activeColor : widget.mutedColor;

    return GestureDetector(
      onTap: _toggle,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) {
          final scale = _micOn ? (1.0 + _pulse.value * 0.12) : 1.0;
          return Transform.scale(scale: scale, child: child);
        },
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 12)],
          ),
          child: Icon(
            _micOn ? Icons.mic : Icons.mic_off,
            color: Colors.white,
            size: 30,
          ),
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
