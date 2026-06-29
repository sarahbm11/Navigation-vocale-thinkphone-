import 'package:flutter/material.dart';
import '../nav_theme.dart';

enum ActiveTier { none, tier1, tier2, tier3 }

class LevelChipsWidget extends StatelessWidget {
  final ActiveTier activeTier;

  const LevelChipsWidget({super.key, this.activeTier = ActiveTier.none});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Chip(label: 'Tier 1', sublabel: 'Local', active: activeTier == ActiveTier.tier1, color: NavColors.success),
        const SizedBox(width: 8),
        _Chip(label: 'Tier 2', sublabel: 'UI Tree', active: activeTier == ActiveTier.tier2, color: NavColors.accent),
        const SizedBox(width: 8),
        _Chip(label: 'IA', sublabel: 'Claude', active: activeTier == ActiveTier.tier3, color: NavColors.primary),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool active;
  final Color color;

  const _Chip({
    required this.label,
    required this.sublabel,
    required this.active,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? color.withOpacity(0.15) : NavColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? color : NavColors.border,
          width: active ? 1.5 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(
              color: active ? color : NavColors.textSecondary,
              fontSize: 11,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            ),
            child: Text(label),
          ),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(
              color: active ? color.withOpacity(0.7) : NavColors.textSecondary.withOpacity(0.5),
              fontSize: 9,
              fontWeight: FontWeight.w400,
            ),
            child: Text(sublabel),
          ),
        ],
      ),
    );
  }
}
