import 'package:flutter/material.dart';
import '../nav_theme.dart';

class VoiceRingWidget extends StatefulWidget {
  final bool active;
  final double size;

  const VoiceRingWidget({super.key, required this.active, this.size = 120});

  @override
  State<VoiceRingWidget> createState() => _VoiceRingWidgetState();
}

class _VoiceRingWidgetState extends State<VoiceRingWidget>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _scales;
  late final List<Animation<double>> _opacities;

  static const _delays = [0, 550, 1100];

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      final c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1800),
      );
      Future.delayed(Duration(milliseconds: _delays[i]), () {
        if (mounted && widget.active) c.repeat();
      });
      return c;
    });

    _scales = _controllers.map((c) =>
      Tween<double>(begin: 1.0, end: 1.5).animate(
        CurvedAnimation(parent: c, curve: Curves.easeOut),
      ),
    ).toList();

    _opacities = _controllers.map((c) =>
      Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeOut),
      ),
    ).toList();
  }

  @override
  void didUpdateWidget(VoiceRingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      if (widget.active) {
        for (var i = 0; i < _controllers.length; i++) {
          Future.delayed(Duration(milliseconds: _delays[i]), () {
            if (mounted) _controllers[i].repeat();
          });
        }
      } else {
        for (final c in _controllers) {
          c.stop();
          c.reset();
        }
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 1.5,
      height: widget.size * 1.5,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < 3; i++)
            AnimatedBuilder(
              animation: _controllers[i],
              builder: (_, __) => Transform.scale(
                scale: _scales[i].value,
                child: Opacity(
                  opacity: _opacities[i].value,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: NavColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Container(
            width: widget.size * 0.6,
            height: widget.size * 0.6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: NavColors.primary.withOpacity(widget.active ? 0.15 : 0.05),
            ),
            child: Icon(
              widget.active ? Icons.mic : Icons.mic_off,
              color: widget.active ? NavColors.primary : NavColors.textSecondary,
              size: widget.size * 0.25,
            ),
          ),
        ],
      ),
    );
  }
}
