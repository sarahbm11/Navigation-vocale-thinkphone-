import 'package:flutter/material.dart';
import '../nav_theme.dart';

class CommandCardWidget extends StatelessWidget {
  final String text;
  final String label;
  final int tier;

  const CommandCardWidget({
    super.key,
    required this.text,
    this.label = '',
    this.tier = 0,
  });

  Color get _tierColor {
    switch (tier) {
      case 1: return NavColors.success;
      case 2: return NavColors.accent;
      case 3: return NavColors.primary;
      default: return NavColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.1),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: _Card(
        key: ValueKey(text + label),
        text: text,
        label: label,
        tierColor: _tierColor,
        tier: tier,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String text;
  final String label;
  final Color tierColor;
  final int tier;

  const _Card({
    super.key,
    required this.text,
    required this.label,
    required this.tierColor,
    required this.tier,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NavColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: NavColors.border),
        ),
        child: Text(
          'En attente d\'une commande…',
          style: NavTheme.caption(),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NavColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tierColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label.isNotEmpty) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: tierColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Text(text, style: NavTheme.body()),
        ],
      ),
    );
  }
}
