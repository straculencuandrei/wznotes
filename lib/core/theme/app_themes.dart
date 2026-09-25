import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/controllers/settings_controller.dart';

/// Curated Palette for Theme Customization
class AppThemePalette {
  final String id;
  final String name;
  final String description;
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color border;
  final Color accent;
  final Color accentSecondary;
  final Color textPrimary;
  final Color textSecondary;

  const AppThemePalette({
    required this.id,
    required this.name,
    required this.description,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.accent,
    required this.accentSecondary,
    this.textPrimary = const Color(0xFFFFFFFF),
    this.textSecondary = const Color(0xFFA0A0A0),
  });
}

class AppThemes {
  // 1. Pure AMOLED (Default - Pitch black with signature Samsung orange)
  static const amoled = AppThemePalette(
    id: 'amoled',
    name: 'Pure AMOLED',
    description: 'Pitch black with classic Samsung orange',
    background: Color(0xFF000000),
    surface: Color(0xFF141414),
    surfaceElevated: Color(0xFF1E1E1E),
    border: Color(0xFF282828),
    accent: Color(0xFFFF6D00),
    accentSecondary: Color(0xFFFF8F00),
  );

  // 2. Midnight Neon (Cyberpunk obsidian with electric cyan glow)
  static const cyber = AppThemePalette(
    id: 'cyber',
    name: 'Midnight Neon',
    description: 'Obsidian void with electric cyan & neon magenta',
    background: Color(0xFF07070E),
    surface: Color(0xFF121222),
    surfaceElevated: Color(0xFF1A1A30),
    border: Color(0xFF282845),
    accent: Color(0xFF00E5FF),
    accentSecondary: Color(0xFFFF007F),
  );

  // 3. Nord Frost (Deep arctic night with crisp ice cyan)
  static const nord = AppThemePalette(
    id: 'nord',
    name: 'Nord Frost',
    description: 'Arctic night palette with soothing frost blues',
    background: Color(0xFF0B0F14),
    surface: Color(0xFF131B26),
    surfaceElevated: Color(0xFF1B2636),
    border: Color(0xFF26374D),
    accent: Color(0xFF38BDF8),
    accentSecondary: Color(0xFF81A1C1),
  );

  // 4. Forest Matrix (Deep obsidian emerald with vivid mint)
  static const forest = AppThemePalette(
    id: 'forest',
    name: 'Forest Matrix',
    description: 'Deep obsidian emerald with vivid mint accents',
    background: Color(0xFF060F0A),
    surface: Color(0xFF0F1E16),
    surfaceElevated: Color(0xFF162B20),
    border: Color(0xFF1E3A2B),
    accent: Color(0xFF00E676),
    accentSecondary: Color(0xFF69F0AE),
  );

  // 5. Warm Sepia (Roasted dark espresso with caramel amber)
  static const sepia = AppThemePalette(
    id: 'sepia',
    name: 'Warm Sepia',
    description: 'Cozy dark espresso with warm caramel amber',
    background: Color(0xFF0E0B08),
    surface: Color(0xFF1C1612),
    surfaceElevated: Color(0xFF28201A),
    border: Color(0xFF3A2E26),
    accent: Color(0xFFFFA726),
    accentSecondary: Color(0xFFFFB74D),
  );

  // 6. Royal Twilight (Deep midnight violet with radiant lavender)
  static const twilight = AppThemePalette(
    id: 'twilight',
    name: 'Royal Twilight',
    description: 'Deep midnight violet with radiant lavender',
    background: Color(0xFF0A0713),
    surface: Color(0xFF161124),
    surfaceElevated: Color(0xFF201934),
    border: Color(0xFF30254C),
    accent: Color(0xFFB388FF),
    accentSecondary: Color(0xFF7C4DFF),
  );

  // 7. Crimson Velvet (Deep velvet obsidian with vivid ruby red glow)
  static const crimson = AppThemePalette(
    id: 'crimson',
    name: 'Crimson Velvet',
    description: 'Deep velvet obsidian with vivid ruby red glow',
    background: Color(0xFF0C0406),
    surface: Color(0xFF190C11),
    surfaceElevated: Color(0xFF26121B),
    border: Color(0xFF3B1A28),
    accent: Color(0xFFFF1744),
    accentSecondary: Color(0xFFF43F5E),
  );

  // 8. Deep Pacific (Abyssal oceanic trench with electric sapphire)
  static const pacific = AppThemePalette(
    id: 'pacific',
    name: 'Deep Pacific',
    description: 'Abyssal oceanic trench with electric sapphire',
    background: Color(0xFF040A12),
    surface: Color(0xFF0A1524),
    surfaceElevated: Color(0xFF102138),
    border: Color(0xFF1C3454),
    accent: Color(0xFF0284C7),
    accentSecondary: Color(0xFF38BDF8),
  );

  // 9. Solar Flare (Eclipse charcoal with fiery solar coral)
  static const solar = AppThemePalette(
    id: 'solar',
    name: 'Solar Flare',
    description: 'Eclipse charcoal with fiery solar coral',
    background: Color(0xFF0C0603),
    surface: Color(0xFF1B0E07),
    surfaceElevated: Color(0xFF2B160C),
    border: Color(0xFF402213),
    accent: Color(0xFFFF5722),
    accentSecondary: Color(0xFFFF8A65),
  );

  // 10. Golden Amber (Imperial dark onyx with radiant molten gold)
  static const gold = AppThemePalette(
    id: 'gold',
    name: 'Golden Amber',
    description: 'Imperial dark onyx with radiant molten gold',
    background: Color(0xFF0B0A04),
    surface: Color(0xFF19160A),
    surfaceElevated: Color(0xFF262110),
    border: Color(0xFF3C3419),
    accent: Color(0xFFFBBF24),
    accentSecondary: Color(0xFFF59E0B),
  );

  // 11. Dracula Noir (Gothic midnight slate with electric orchid)
  static const dracula = AppThemePalette(
    id: 'dracula',
    name: 'Dracula Noir',
    description: 'Gothic midnight slate with electric orchid',
    background: Color(0xFF0A0912),
    surface: Color(0xFF141324),
    surfaceElevated: Color(0xFF1D1B34),
    border: Color(0xFF2E2B4E),
    accent: Color(0xFFBD93F9),
    accentSecondary: Color(0xFF50FA7B),
  );

  // 12. Carbon Silver (Pure minimalist carbon with surgical silver)
  static const carbon = AppThemePalette(
    id: 'carbon',
    name: 'Carbon Silver',
    description: 'Pure minimalist carbon with surgical silver',
    background: Color(0xFF050505),
    surface: Color(0xFF141414),
    surfaceElevated: Color(0xFF202020),
    border: Color(0xFF333333),
    accent: Color(0xFFE2E8F0),
    accentSecondary: Color(0xFF94A3B8),
  );

  static List<AppThemePalette> get allThemes => [
        amoled,
        cyber,
        nord,
        forest,
        sepia,
        twilight,
        crimson,
        pacific,
        solar,
        gold,
        dracula,
        carbon,
      ];

  static AppThemePalette getTheme(String id) {
    return allThemes.firstWhere(
      (t) => t.id == id,
      orElse: () => amoled,
    );
  }

  static ThemeData getThemeData(String id) {
    final palette = getTheme(id);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: palette.accent,
        onPrimary: Colors.black,
        secondary: palette.accentSecondary,
        surface: palette.surface,
        outline: palette.border,
      ),
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      tabBarTheme: TabBarThemeData(
        indicatorColor: palette.accent,
      ),
      fontFamily: 'Inter',
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.accent,
        selectionColor: palette.accent.withValues(alpha: 0.3),
        selectionHandleColor: palette.accent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: palette.textPrimary, size: 26),
        titleTextStyle: TextStyle(
          color: palette.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          fontFamily: 'Inter',
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: palette.border, width: 1.2),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),
    );
  }
}

final appThemeProvider = Provider<AppThemePalette>((ref) {
  final themeId = ref.watch(settingsProvider.select((s) => s.themeId));
  return AppThemes.getTheme(themeId);
});
