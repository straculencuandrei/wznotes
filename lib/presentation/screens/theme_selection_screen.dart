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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Themes & Appearance',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
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

          // 2. Curated Themes Grid / List
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
            child: Text(
              'CURATED AMOLED PALETTES (${AppThemes.allThemes.length})',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: activeTheme.accent,
                letterSpacing: 1.0,
              ),
            ),
          ),

          Container(
            decoration: BoxDecoration(
              color: activeTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: activeTheme.border, width: 1.2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: AppThemes.allThemes.length,
                separatorBuilder: (context, index) => Divider(color: activeTheme.border, height: 1),
                itemBuilder: (context, index) {
                  final theme = AppThemes.allThemes[index];
                  final isSelected = theme.id == settings.themeId;

                  return InkWell(
                    onTap: () {
                      settingsNotifier.setTheme(theme.id);
                      TopIslandToast.show(
                        context,
                        message: '${theme.name} theme applied',
                        icon: Icons.palette_outlined,
                        color: theme.accent,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 13.0),
                      child: Row(
                        children: [
                          // 3-color palette preview capsule
                          Container(
                            width: 52,
                            height: 36,
                            decoration: BoxDecoration(
                              color: theme.background,
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
                                      color: theme.surface,
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
                                Text(
                                  theme.name,
                                  style: TextStyle(
                                    color: isSelected ? theme.accent : Colors.white,
                                    fontSize: 15.5,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  ),
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
                            const Icon(Icons.circle_outlined, color: Colors.white24, size: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
