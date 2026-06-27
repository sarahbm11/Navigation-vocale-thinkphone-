import 'package:flutter/material.dart';
import '../navigation_vocale_sdk.dart';
import '../models/voice_command.dart';
import 'voice_nav_button.dart';

/// Overlay draggable affiché par-dessus toute l'application.
/// Montre les commandes reconnues et contrôle le micro.
class VoiceNavOverlay extends StatefulWidget {
  final NavigationVocaleSDK sdk;

  const VoiceNavOverlay({super.key, required this.sdk});

  @override
  State<VoiceNavOverlay> createState() => _VoiceNavOverlayState();
}

class _VoiceNavOverlayState extends State<VoiceNavOverlay> {
  Offset _position = const Offset(20, 100);
  String _lastCommand = '';
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    widget.sdk.onCommand.listen((cmd) {
      if (!mounted) return;
      setState(() => _lastCommand = _label(cmd));
    });
  }

  String _label(VoiceCommand cmd) {
    if (cmd.type == CommandType.unknown) return '❓ "${cmd.rawText}"';
    final param = cmd.parameter != null ? ' · ${cmd.parameter}' : '';
    return '${_icon(cmd.type)} ${cmd.type.name}$param';
  }

  String _icon(CommandType t) {
    switch (t) {
      case CommandType.home:       return '🏠';
      case CommandType.back:       return '⬅️';
      case CommandType.recents:    return '⧉';
      case CommandType.notifications: return '🔔';
      case CommandType.openApp:    return '📱';
      case CommandType.closeApp:   return '✖️';
      case CommandType.scrollDown: return '⬇️';
      case CommandType.scrollUp:   return '⬆️';
      case CommandType.swipeLeft:  return '◀';
      case CommandType.swipeRight: return '▶';
      case CommandType.tap:        return '👆';
      case CommandType.longPress:  return '✋';
      case CommandType.micOn:      return '🎙️';
      case CommandType.micOff:     return '🔇';
      case CommandType.stop:       return '⏹️';
      case CommandType.unknown:    return '❓';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (d) => setState(() => _position += d.delta),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Material(
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.78),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VoiceNavButton(sdk: widget.sdk),
                    if (_expanded) ...[
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Navigation Vocale',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          if (_lastCommand.isNotEmpty)
                            Text(
                              _lastCommand,
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                        ],
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
