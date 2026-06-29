import 'package:flutter/material.dart';
import 'package:navigation_vocale/src/ui/nav_theme.dart';
import 'main_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NavVocaleApp());
}

class NavVocaleApp extends StatelessWidget {
  const NavVocaleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Navigation Vocale',
      debugShowCheckedModeBanner: false,
      theme: NavTheme.theme(),
      home: const MainScreen(),
    );
  }
}
