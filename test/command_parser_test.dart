import 'package:flutter_test/flutter_test.dart';
import 'package:navigation_vocale/src/utils/command_parser.dart';
import 'package:navigation_vocale/src/models/voice_command.dart';

void main() {
  group('CommandParser — Navigation système', () {
    test('Accueil FR', () {
      expect(CommandParser.parse('accueil').type, CommandType.home);
    });
    test('Home EN', () {
      expect(CommandParser.parse('home').type, CommandType.home);
    });
    test('Retour FR', () {
      expect(CommandParser.parse('retour').type, CommandType.back);
    });
    test('Back EN', () {
      expect(CommandParser.parse('back').type, CommandType.back);
    });
    test('Applications récentes', () {
      expect(CommandParser.parse('applications récentes').type, CommandType.recents);
    });
    test('Notifications', () {
      expect(CommandParser.parse('notifications').type, CommandType.notifications);
    });
    test('Fermer', () {
      expect(CommandParser.parse('fermer').type, CommandType.closeApp);
    });
  });

  group('CommandParser — Ouvrir application', () {
    test('Ouvrir Caméra', () {
      final cmd = CommandParser.parse('ouvrir caméra');
      expect(cmd.type, CommandType.openApp);
      expect(cmd.parameter, 'caméra');
    });
    test('Open Maps EN', () {
      final cmd = CommandParser.parse('open maps');
      expect(cmd.type, CommandType.openApp);
      expect(cmd.parameter, 'maps');
    });
    test('Lancer Spotify', () {
      final cmd = CommandParser.parse('lancer spotify');
      expect(cmd.type, CommandType.openApp);
      expect(cmd.parameter, 'spotify');
    });
  });

  group('CommandParser — Défilement', () {
    test('Défiler vers le bas', () {
      expect(CommandParser.parse('défiler vers le bas').type, CommandType.scrollDown);
    });
    test('Défiler vers le haut', () {
      expect(CommandParser.parse('défiler vers le haut').type, CommandType.scrollUp);
    });
    test('Glisser gauche', () {
      expect(CommandParser.parse('glisser gauche').type, CommandType.swipeLeft);
    });
    test('Swipe right EN', () {
      expect(CommandParser.parse('swipe right').type, CommandType.swipeRight);
    });
  });

  group('CommandParser — Tap', () {
    test('Appuyer sur OK', () {
      final cmd = CommandParser.parse('appuyer sur ok');
      expect(cmd.type, CommandType.tap);
      expect(cmd.parameter, 'ok');
    });
    test('Cliquer sur Envoyer', () {
      final cmd = CommandParser.parse('cliquer sur envoyer');
      expect(cmd.type, CommandType.tap);
      expect(cmd.parameter, 'envoyer');
    });
    test('Appui long', () {
      expect(CommandParser.parse('appui long').type, CommandType.longPress);
    });
  });

  group('CommandParser — Contrôle micro', () {
    test('Micro off', () {
      expect(CommandParser.parse('micro off').type, CommandType.micOff);
    });
    test('Couper le micro', () {
      expect(CommandParser.parse('couper le micro').type, CommandType.micOff);
    });
    test('Micro on', () {
      expect(CommandParser.parse('micro on').type, CommandType.micOn);
    });
    test('Silence', () {
      expect(CommandParser.parse('silence').type, CommandType.micOff);
    });
  });

  group('CommandParser — Arrêt', () {
    test('Arrêter', () {
      expect(CommandParser.parse('arrêter').type, CommandType.stop);
    });
    test('Stop', () {
      expect(CommandParser.parse('stop').type, CommandType.stop);
    });
  });

  group('CommandParser — Inconnu', () {
    test('Phrase aléatoire', () {
      expect(CommandParser.parse('bonjour comment ça va').type, CommandType.unknown);
    });
    test('Texte vide', () {
      expect(CommandParser.parse('').type, CommandType.unknown);
    });
  });
}
