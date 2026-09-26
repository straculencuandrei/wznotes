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
  final Gradient? backgroundGradient;
  final bool isDark;

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
    this.backgroundGradient,
    this.isDark = true,
  });
}

class AppThemes {
  // ==================== DYNAMIC MULTI-COLOR GRADIENT PALETTES ====================

  // 1. Moonwalker (uiGradients: #152331 -> #000000)
  static const moonwalker = AppThemePalette(
    id: 'moonwalker',
    name: 'Moonwalker',
    description: 'Deep space atmospheric fade from dark stone navy into pure obsidian black',
    background: Color(0xFF152331),
    backgroundGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF152331), Color(0xFF000000)],
      stops: [0.0, 1.0],
    ),
    surface: Color(0xFF1A2634),
    surfaceElevated: Color(0xFF233346),
    border: Color(0xFF34495E),
    accent: Color(0xFF4FC3F7),
    accentSecondary: Color(0xFF90CAF9),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB0BEC5),
  );

  // 2. Ameena (uiGradients: #0C0C6D -> #DE512B -> #98D0C1 -> #5BB226 -> #023C0D)
  static const ameena = AppThemePalette(
    id: 'ameena',
    name: 'Ameena',
    description: 'Rich multi-chroma fade: deep midnight indigo, warm flame, sage mint, and lush forest emerald',
    background: Color(0xFF0C0C6D),
    backgroundGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0C0C6D),
        Color(0xFFDE512B),
        Color(0xFF98D0C1),
        Color(0xFF5BB226),
        Color(0xFF023C0D),
      ],
      stops: [0.0, 0.25, 0.50, 0.75, 1.0],
    ),
    surface: Color(0xFF14145A),
    surfaceElevated: Color(0xFF1F1E74),
    border: Color(0xFF38358E),
    accent: Color(0xFF98D0C1),
    accentSecondary: Color(0xFFFF6E40),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFD4E6E1),
  );

  // 3. Winter Woods (uiGradients: #333333 -> #A2AB58 -> #A43931)
  static const winterWoods = AppThemePalette(
    id: 'winter_woods',
    name: 'Winter Woods',
    description: 'Rustic woodland fade: charcoal timber, mossy olive gold, and deep carmine amber',
    background: Color(0xFF333333),
    backgroundGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF333333),
        Color(0xFFA2AB58),
        Color(0xFFA43931),
      ],
      stops: [0.0, 0.50, 1.0],
    ),
    surface: Color(0xFF3B3B3B),
    surfaceElevated: Color(0xFF4A4A4A),
    border: Color(0xFF5E5E5E),
    accent: Color(0xFFDCE775),
    accentSecondary: Color(0xFFFF8A80),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFE4E4D0),
  );

  // 4. Yoda (uiGradients: #FF0099 -> #493240)
  static const yoda = AppThemePalette(
    id: 'yoda',
    name: 'Yoda',
    description: 'High-voltage electric duo-chroma: intense neon cerise pink melting into deep plum obsidian',
    background: Color(0xFF493240),
    backgroundGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFF0099), Color(0xFF493240)],
      stops: [0.0, 1.0],
    ),
    surface: Color(0xFF3B2032),
    surfaceElevated: Color(0xFF4E2842),
    border: Color(0xFF6F355E),
    accent: Color(0xFFFF40B4),
    accentSecondary: Color(0xFFFF80DF),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFF0CEE3),
  );

  // Legacy compatibility aliases for previously saved user preferences
  static const prismRgb = moonwalker;
  static const cyberSunset = ameena;
  static const auroraBorealis = winterWoods;
  static const hyperPop = yoda;

  // ==================== WHITE & BRIGHTISH GRADIENT PALETTES ====================

  // 5. Ethereal Pearl (Preserved White Light Mode - Soft Porcelain & Cool Slate)
  static const etherealPearl = AppThemePalette(
    id: 'ethereal_pearl',
    name: 'Ethereal Pearl',
    description: 'Luminous alabaster pearl fading into cool ethereal porcelain and slate',
    background: Color(0xFFF1F5F9),
    backgroundGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFAFBFD), Color(0xFFEEF3F8), Color(0xFFE2E8F0), Color(0xFFF4F7FB)],
      stops: [0.0, 0.35, 0.75, 1.0],
    ),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    border: Color(0xFFCBD5E1),
    accent: Color(0xFF2563EB),
    accentSecondary: Color(0xFF6366F1),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    isDark: false,
  );

  // 6. Wabi Parchment (Preserved White/Warm Paper Light Mode - Japanese Editorial Fade)
  static const wabiParchment = AppThemePalette(
    id: 'wabi_parchment',
    name: 'Wabi Parchment',
    description: 'Warm vintage Japanese paper fading through tranquil oat and sand shades',
    background: Color(0xFFF4EDE4),
    backgroundGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFBF8F3), Color(0xFFF3ECE1), Color(0xFFE8DECF), Color(0xFFF6F0E6)],
      stops: [0.0, 0.3, 0.75, 1.0],
    ),
    surface: Color(0xFFFFFDF9),
    surfaceElevated: Color(0xFFFFFFFF),
    border: Color(0xFFD6C8B8),
    accent: Color(0xFFC2410C),
    accentSecondary: Color(0xFFD97706),
    textPrimary: Color(0xFF261E17),
    textSecondary: Color(0xFF6E5D4F),
    isDark: false,
  );

  // 7. Solaris Dawn (Brightish - Luminous Golden Peach -> Pastel Coral Rose -> Soft Morning Lilac)
  static const solarisDawn = AppThemePalette(
    id: 'solaris_dawn',
    name: 'Solaris Dawn',
    description: 'Bright radiant sunrise: warm golden ivory fading into coral rose and soft morning lavender',
    background: Color(0xFFFFF7ED),
    backgroundGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFFBF5), Color(0xFFFFE8EC), Color(0xFFF4EBFF), Color(0xFFFAF5FF)],
      stops: [0.0, 0.35, 0.75, 1.0],
    ),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    border: Color(0xFFFED7AA),
    accent: Color(0xFFE11D48),
    accentSecondary: Color(0xFFEA580C),
    textPrimary: Color(0xFF1E1B4B),
    textSecondary: Color(0xFF64748B),
    isDark: false,
  );

  // 8. Sakura Matcha (Brightish - Dew Spring Mint -> Fresh Jade -> Soft Cherry Blossom Pink)
  static const sakuraMatcha = AppThemePalette(
    id: 'sakura_matcha',
    name: 'Sakura Matcha',
    description: 'Bright botanical harmony: spring matcha mint softly fading into sweet cherry blossom pink',
    background: Color(0xFFF0FDF4),
    backgroundGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFF5FCF7), Color(0xFFE6F8EE), Color(0xFFFDF2F8), Color(0xFFFBFBFE)],
      stops: [0.0, 0.3, 0.7, 1.0],
    ),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    border: Color(0xFFBBF7D0),
    accent: Color(0xFF059669),
    accentSecondary: Color(0xFFF43F5E),
    textPrimary: Color(0xFF064E3B),
    textSecondary: Color(0xFF475569),
    isDark: false,
  );

  // 9. Celestial Opal (Brightish - Cool Sky Ice -> Soft Lavender Amethyst -> Sunlight Cream)
  static const celestialOpal = AppThemePalette(
    id: 'celestial_opal',
    name: 'Celestial Opal',
    description: 'Bright iridescent glow: crisp sky ice blue fading into ethereal lavender and sunlight cream',
    background: Color(0xFFF0F9FF),
    backgroundGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF6FAFE), Color(0xFFF3F0FF), Color(0xFFFEFCE8), Color(0xFFFAF5FF)],
      stops: [0.0, 0.35, 0.75, 1.0],
    ),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    border: Color(0xFFC7D2FE),
    accent: Color(0xFF2563EB),
    accentSecondary: Color(0xFF7C3AED),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    isDark: false,
  );

  // ==================== ORIGINAL SOLID PALETTES ====================

  // 10. Pure AMOLED (Default - Pitch black with signature Samsung orange)
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

  // 11. Midnight Neon (Cyberpunk obsidian with electric cyan glow)
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

  // 12. Nord Frost (Deep arctic night with crisp ice cyan)
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

  // 13. Forest Matrix (Deep obsidian emerald with vivid mint)
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

  // 14. Warm Sepia (Roasted dark espresso with caramel amber)
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

  // 15. Royal Twilight (Deep midnight violet with radiant lavender)
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

  // 16. Crimson Velvet (Deep velvet obsidian with vivid ruby red glow)
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

  // 17. Deep Pacific (Abyssal oceanic trench with electric sapphire)
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

  // 18. Solar Flare (Eclipse charcoal with fiery solar coral)
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

  // 19. Golden Amber (Imperial dark onyx with radiant molten gold)
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

  // 20. Dracula Noir (Gothic midnight slate with electric orchid)
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

  // 21. Carbon Silver (Pure minimalist carbon with surgical silver)
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

  /// Curated Multi-Color & Brightish Gradient Themes
  static List<AppThemePalette> get gradientThemes => [
        moonwalker,
        ameena,
        winterWoods,
        yoda,
        etherealPearl,
        wabiParchment,
        solarisDawn,
        sakuraMatcha,
        celestialOpal,
      ];

  /// Curated Solid Minimalist & Classic Palettes
  static List<AppThemePalette> get solidThemes => [
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

  static List<AppThemePalette> get allThemes => [
        ...gradientThemes,
        ...solidThemes,
      ];

  static AppThemePalette getTheme(String id) {
    if (id == 'prism_rgb') return moonwalker;
    if (id == 'cyber_sunset') return ameena;
    if (id == 'aurora_borealis') return winterWoods;
    if (id == 'hyper_pop') return yoda;
    return allThemes.firstWhere(
      (t) => t.id == id,
      orElse: () => amoled,
    );
  }

  static ThemeData getThemeData(String id) {
    final palette = getTheme(id);
    final isDark = palette.isDark;

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: palette.accent,
              onPrimary: Colors.black,
              secondary: palette.accentSecondary,
              surface: palette.surface,
              outline: palette.border,
            )
          : ColorScheme.light(
              primary: palette.accent,
              onPrimary: Colors.white,
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
