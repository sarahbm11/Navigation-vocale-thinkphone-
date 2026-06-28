import 'package:flutter/material.dart';
import '../nav_theme.dart';

class WaveformWidget extends StatefulWidget {
  final bool active;
  final double height;

  const WaveformWidget({super.key, required this.active, this.height = 40});

  @override
  State<WaveformWidget> createState() => _WaveformWidgetState();
}

class _WaveformWidgetState extends State<WaveformWidget>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _heights;

  static const _delays = [0, 120, 60, 220, 80, 180, 40];

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(7, (i) {
      final c = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 400 + _delays[i]),
      );
      if (widget.active) {
        Future.delayed(Duration(milliseconds: _delays[i]), () {
          if (mounted) c.repeat(reverse: true);
        });
      }
      return c;
    });

    _heights = _controllers.map((c) =>
      Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      ),
    ).toList();
  }

  @override
  void didUpdateWidget(WaveformWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      if (widget.active) {
        for (var i = 0; i < _controllers.length; i++) {
          Future.delayed(Duration(milliseconds: _delays[i]), () {
            if (mounted) _controllers[i].repeat(reverse: true);
          });
        }
      } else {
        for (final c in _controllers) {
          c.animateTo(0.3);
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
      height: widget.height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(7, (i) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: AnimatedBuilder(
              animation: _controllers[i],
              builder: (_, __) => Container(
                width: 4,
                height: widget.height * _heights[i].value,
                decoration: BoxDecoration(
                  color: widget.active
                      ? NavColors.primary
                      : NavColors.textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
