import 'package:flutter/material.dart';

/// True AMOLED Pitch-Black Color Palette inspired by Samsung One UI
class AppColors {
  // Brand & Accent (Samsung Warm Amber & Electric Accent)
  static const Color samsungOrange = Color(0xFFFF6D00);
  static const Color samsungAmber = Color(0xFFFF8F00);
  static const Color primaryBlue = Color(0xFF2979FF);
  static const Color accentIndigo = Color(0xFF651FFF);
  static const Color accentRose = Color(0xFFFF1744);
  static const Color accentEmerald = Color(0xFF00E676);

  // Pure AMOLED Pitch Black Theme (0x000000)
  static const Color amoledBlack = Color(0xFF000000);
  static const Color amoledSurface = Color(0xFF141414);
  static const Color amoledSurfaceElevated = Color(0xFF1E1E1E);
  static const Color amoledBorder = Color(0xFF282828);
  static const Color amoledTextPrimary = Color(0xFFFFFFFF);
  static const Color amoledTextSecondary = Color(0xFFA0A0A0);

  // Aliases for Dark Theme Compatibility
  static const Color darkBg = Color(0xFF000000);
  static const Color darkPaper = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF141414);
  static const Color darkSurfaceElevated = Color(0xFF1E1E1E);
  static const Color darkBorder = Color(0xFF282828);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFA0A0A0);
  static const Color darkRuledLine = Color(0xFF242424);

  // Fallback Light Theme
  static const Color lightBg = Color(0xFFF6F8FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE1E4E8);
  static const Color lightTextPrimary = Color(0xFF111827);
  static const Color lightTextSecondary = Color(0xFF6B7280);

  // Default Inks
  static const Color primaryLightInk = Color(0xFFFFFFFF);
  static const Color primaryDarkInk = Color(0xFF000000);

  // Ink Palette
  static const List<Color> inkPalette = [
    Color(0xFFFFFFFF), // White
    Color(0xFFFF6D00), // Samsung Orange
    Color(0xFF2979FF), // Electric Blue
    Color(0xFFFF1744), // Crimson
    Color(0xFF00E676), // Spring Green
    Color(0xFFFFEA00), // Electric Yellow
  ];
}
