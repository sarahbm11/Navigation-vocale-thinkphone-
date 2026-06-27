/// Représente un élément UI visible sur l'écran Android.
/// Fourni par AccessibilityService — rien n'est enregistré ni transmis.
class ScreenNode {
  final String? text;
  final String? contentDescription;
  final String? className;
  final bool isClickable;
  final bool isEditable;
  final bool isScrollable;
  final bool isFocused;
  final int left;
  final int top;
  final int right;
  final int bottom;

  const ScreenNode({
    this.text,
    this.contentDescription,
    this.className,
    required this.isClickable,
    required this.isEditable,
    required this.isScrollable,
    required this.isFocused,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  /// Label lisible combinant texte + description.
  String get label {
    final parts = [text, contentDescription]
        .where((s) => s != null && s.isNotEmpty)
        .toList();
    return parts.join(' / ');
  }

  /// Centre de l'élément (pour un tap par coordonnée).
  (double, double) get center => (
        (left + right) / 2.0,
        (top + bottom) / 2.0,
      );

  factory ScreenNode.fromMap(Map<Object?, Object?> m) => ScreenNode(
        text: m['text'] as String?,
        contentDescription: m['desc'] as String?,
        className: m['class'] as String?,
        isClickable: (m['clickable'] as bool?) ?? false,
        isEditable: (m['editable'] as bool?) ?? false,
        isScrollable: (m['scrollable'] as bool?) ?? false,
        isFocused: (m['focused'] as bool?) ?? false,
        left: (m['left'] as int?) ?? 0,
        top: (m['top'] as int?) ?? 0,
        right: (m['right'] as int?) ?? 0,
        bottom: (m['bottom'] as int?) ?? 0,
      );

  @override
  String toString() => 'ScreenNode("$label" click=$isClickable edit=$isEditable)';
}
