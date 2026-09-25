import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_themes.dart';
import '../controllers/settings_controller.dart';
import '../widgets/top_island_toast.dart';

class ThemeSelectionScreen extends ConsumerWidget {
  const ThemeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final activeTheme = ref.watch(appThemeProvider);

    return Scaffold(
      backgroundColor: activeTheme.background,
      appBar: AppBar(
        backgroundColor: activeTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: activeTheme.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Themes & Appearance',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: activeTheme.textPrimary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        physics: const BouncingScrollPhysics(),
        children: [
          // 1. Live Interactive Preview Card
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
            child: Text(
              'LIVE PREVIEW',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: activeTheme.accent,
                letterSpacing: 1.0,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: activeTheme.surface,
              gradient: activeTheme.backgroundGradient,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: activeTheme.accent, width: 1.8),
              boxShadow: [
                BoxShadow(
                  color: activeTheme.accent.withValues(alpha: 0.15),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Preview Note',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: activeTheme.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: activeTheme.accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        activeTheme.name,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: activeTheme.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'The quick brown fox jumps over the lazy dog. Stylus inking, caret animations, and UI highlights automatically adapt to your theme.',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: activeTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: activeTheme.accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Accents & borders synchronized',
                      style: TextStyle(fontSize: 11.5, color: activeTheme.accent, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const SizedBox(height: 24),

          // 2. Dynamic Gradient Themes Section
          _buildSectionHeader(
            title: 'DYNAMIC GRADIENTS & COLOR FADES',
            badge: '${AppThemes.gradientThemes.length} PALETTES',
            subtitle: 'Vibrant RGB chromatic fades, multi-color blends & bright themes',
            accentColor: activeTheme.accent,
            textColor: activeTheme.textSecondary,
          ),
          const SizedBox(height: 8),
          _buildThemeGroupCard(
            context: context,
            themes: AppThemes.gradientThemes,
            selectedThemeId: settings.themeId,
            activeTheme: activeTheme,
            onSelectTheme: (id, name, accent) {
              settingsNotifier.setTheme(id);
              TopIslandToast.show(
                context,
                message: '$name theme applied',
                icon: Icons.palette_outlined,
                color: accent,
              );
            },
          ),

          const SizedBox(height: 28),

          // 3. Solid & Minimalist Palettes Section
          _buildSectionHeader(
            title: 'SOLID & MINIMALIST PALETTES',
            badge: '${AppThemes.solidThemes.length} PALETTES',
            subtitle: 'Pitch black AMOLED, cyber darks, and clean timeless tones',
            accentColor: activeTheme.accent,
            textColor: activeTheme.textSecondary,
          ),
          const SizedBox(height: 8),
          _buildThemeGroupCard(
            context: context,
            themes: AppThemes.solidThemes,
            selectedThemeId: settings.themeId,
            activeTheme: activeTheme,
            onSelectTheme: (id, name, accent) {
              settingsNotifier.setTheme(id);
              TopIslandToast.show(
                context,
                message: '$name theme applied',
                icon: Icons.palette_outlined,
                color: accent,
              );
            },
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String badge,
    required String subtitle,
    required Color accentColor,
    required Color textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, right: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                  letterSpacing: 1.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: textColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeGroupCard({
    required BuildContext context,
    required List<AppThemePalette> themes,
    required String selectedThemeId,
    required AppThemePalette activeTheme,
    required void Function(String id, String name, Color accent) onSelectTheme,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: activeTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: activeTheme.border, width: 1.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Theme(
          data: ThemeData(
            splashColor: activeTheme.accent.withValues(alpha: 0.15),
            highlightColor: Colors.transparent,
            splashFactory: InkRipple.splashFactory,
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                for (int index = 0; index < themes.length; index++) ...[
                  if (index > 0) Divider(color: activeTheme.border, height: 1),
                  () {
                    final theme = themes[index];
                    final isSelected = theme.id == selectedThemeId;
                    final isFirst = index == 0;
                    final isLast = index == themes.length - 1;

                    return InkWell(
                      borderRadius: BorderRadius.vertical(
                        top: isFirst ? const Radius.circular(19) : Radius.zero,
                        bottom: isLast ? const Radius.circular(19) : Radius.zero,
                      ),
                      onTap: () => onSelectTheme(theme.id, theme.name, theme.accent),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 13.0),
                        child: Row(
                          children: [
                            // Palette preview capsule showing gradient or dual-tone
                            Container(
                              width: 52,
                              height: 36,
                              decoration: BoxDecoration(
                                color: theme.background,
                                gradient: theme.backgroundGradient,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? theme.accent : theme.border,
                                  width: isSelected ? 2.0 : 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: theme.backgroundGradient != null ? Colors.transparent : theme.surface,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(8),
                                          bottomLeft: Radius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 14,
                                    decoration: BoxDecoration(
                                      color: theme.accent,
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(8),
                                        bottomRight: Radius.circular(8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        theme.name,
                                        style: TextStyle(
                                          color: isSelected ? theme.accent : activeTheme.textPrimary,
                                          fontSize: 15.5,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        ),
                                      ),
                                      if (!theme.isDark) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: theme.accent.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          child: Text(
                                            'Light',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: theme.accent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    theme.description,
                                    style: TextStyle(
                                      color: activeTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(Icons.check_circle_rounded, color: theme.accent, size: 22)
                            else
                              Icon(Icons.circle_outlined, color: activeTheme.border, size: 20),
                          ],
                        ),
                      ),
                    );
                  }(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
