import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract class NavColors {
  static const background    = Color(0xFF0A0B0E);
  static const surface       = Color(0xFF141518);
  static const primary       = Color(0xFFE8FF47);
  static const accent        = Color(0xFF8A2BE2);
  static const danger        = Color(0xFFFF3B30);
  static const success       = Color(0xFF00D26A);
  static const text          = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF8B8FA8);
  static const border        = Color(0xFF252730);
}

abstract class NavTheme {
  static TextStyle title() => GoogleFonts.spaceGrotesk(
    color: NavColors.text,
    fontSize: 24,
    fontWeight: FontWeight.w700,
  );

  static TextStyle body() => GoogleFonts.spaceGrotesk(
    color: NavColors.text,
    fontSize: 16,
    fontWeight: FontWeight.w400,
  );

  static TextStyle caption() => GoogleFonts.spaceGrotesk(
    color: NavColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  static TextStyle mono({double letterSpacing = 0.0}) => GoogleFonts.jetBrainsMono(
    color: NavColors.text,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: letterSpacing,
  );

  static ThemeData theme() => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: NavColors.background,
    colorScheme: const ColorScheme.dark(
      primary: NavColors.primary,
      secondary: NavColors.accent,
      surface: NavColors.surface,
      error: NavColors.danger,
    ),
    textTheme: GoogleFonts.spaceGroteskTextTheme(ThemeData.dark().textTheme),
  );
}
