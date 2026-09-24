import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_themes.dart';
import '../controllers/settings_controller.dart';
import '../controllers/notes_library_controller.dart';
import '../../infrastructure/security/biometric_service.dart';
import '../../infrastructure/update/update_service.dart';
import '../controllers/update_controller.dart';
import '../widgets/update_dialog.dart';
import '../widgets/top_island_toast.dart';
import '../widgets/export_dialog.dart';
import 'sync_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final libraryState = ref.watch(notesLibraryProvider);
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
          'Settings',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        physics: const BouncingScrollPhysics(),
        children: [
          // 1. Appearance & Curated Themes Section
          _buildSectionHeader('Appearance & Themes', activeTheme.accent),
          _buildCard(
            activeTheme: activeTheme,
            children: [
              ...AppThemes.allThemes.map((theme) {
                final isSelected = theme.id == settings.themeId;
                return Column(
                  children: [
                    InkWell(
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
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        child: Row(
                          children: [
                            // Theme color preview circle
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: theme.surfaceElevated,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? theme.accent : theme.border,
                                  width: isSelected ? 2.2 : 1.2,
                                ),
                              ),
                              child: Center(
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: theme.accent,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: theme.accent.withValues(alpha: 0.5),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
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
                    ),
                    if (theme != AppThemes.allThemes.last)
                      Divider(color: activeTheme.border, height: 1),
                  ],
                );
              }),
            ],
          ),

          const SizedBox(height: 24),

          // 2. Security & PIN Section
          _buildSectionHeader('Security & PIN', activeTheme.accent),
          _buildCard(
            activeTheme: activeTheme,
            children: [
              if (Platform.isAndroid || Platform.isIOS) ...[
                SwitchListTile(
                  activeThumbColor: activeTheme.accent,
                  title: const Text('Fingerprint / Face Unlock', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Require biometrics to open locked notes', style: TextStyle(color: AppColors.amoledTextSecondary, fontSize: 13)),
                  value: settings.isBiometricEnabled,
                  onChanged: (val) async {
                    if (val) {
                      final authed = await BiometricSecurityService.authenticate(reason: 'Verify fingerprint to enable biometric lock');
                      if (authed) {
                        settingsNotifier.toggleBiometrics(true);
                      }
                    } else {
                      settingsNotifier.toggleBiometrics(false);
                    }
                  },
                ),
                Divider(color: activeTheme.border, height: 1),
              ],
              ListTile(
                leading: Icon(Icons.pin_rounded, color: activeTheme.accent),
                title: const Text('Set / Change Master PIN', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  settings.appPin == '1234'
                      ? 'Default PIN: 1234 (Tap to set custom PIN)'
                      : 'Custom PIN active (••••)',
                  style: const TextStyle(color: AppColors.amoledTextSecondary, fontSize: 13),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                onTap: () async {
                  bool canProceed = true;
                  if (settings.appPin != '1234') {
                    canProceed = await BiometricSecurityService.promptPin(
                      context,
                      correctPin: settings.appPin,
                      title: 'Enter Current PIN',
                    );
                  }

                  if (canProceed && context.mounted) {
                    final newPin = await BiometricSecurityService.promptSetPin(
                      context,
                      title: 'Set New Master PIN',
                    );
                    if (newPin != null && context.mounted) {
                      settingsNotifier.setPin(newPin);
                      ref.read(notesLibraryProvider.notifier).updateLockPinForLockedNotes(newPin);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Master PIN updated to $newPin'),
                          backgroundColor: AppColors.accentEmerald,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 3. Editor & Writing Preferences
          _buildSectionHeader('Writing & Editor', activeTheme.accent),
          _buildCard(
            activeTheme: activeTheme,
            children: [
              ListTile(
                title: const Text('Editor Font Size', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                subtitle: Text('${settings.fontSize.toInt()}sp (Default)', style: const TextStyle(color: AppColors.amoledTextSecondary, fontSize: 13)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, color: Colors.white70),
                      onPressed: settings.fontSize > 13 ? () => settingsNotifier.setFontSize(settings.fontSize - 2) : null,
                    ),
                    Text('${settings.fontSize.toInt()}', style: TextStyle(color: activeTheme.accent, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.white70),
                      onPressed: settings.fontSize < 25 ? () => settingsNotifier.setFontSize(settings.fontSize + 2) : null,
                    ),
                  ],
                ),
              ),
              Divider(color: activeTheme.border, height: 1),
              SwitchListTile(
                activeThumbColor: activeTheme.accent,
                title: const Text('VSCode Smooth Caret Effect', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                subtitle: const Text('Smooth animated typing cursor', style: TextStyle(color: AppColors.amoledTextSecondary, fontSize: 13)),
                value: settings.smoothCaretEnabled,
                onChanged: (val) => settingsNotifier.toggleSmoothCaret(val),
              ),
              Divider(color: activeTheme.border, height: 1),
              SwitchListTile(
                activeThumbColor: activeTheme.accent,
                title: const Text('Show Word Count', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                subtitle: const Text('Display real-time word counter in note header & library', style: TextStyle(color: AppColors.amoledTextSecondary, fontSize: 13)),
                value: settings.showWordCount,
                onChanged: (val) => settingsNotifier.toggleWordCount(val),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 4. Storage & Sync
          _buildSectionHeader('Storage & Sync', activeTheme.accent),
          _buildCard(
            activeTheme: activeTheme,
            children: [
              ListTile(
                title: const Text('Total Notes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                trailing: Text('${libraryState.notes.length}', style: TextStyle(color: activeTheme.accent, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              Divider(color: activeTheme.border, height: 1),
              ListTile(
                leading: Icon(Icons.sync_alt_rounded, color: activeTheme.accent),
                title: const Text('Wi-Fi Device Sync', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                subtitle: const Text('Sync notes between Phone & PC over local network', style: TextStyle(color: AppColors.amoledTextSecondary, fontSize: 13)),
                trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const SyncScreen()),
                  );
                },
              ),
              Divider(color: activeTheme.border, height: 1),
              ListTile(
                leading: Icon(Icons.folder_zip_outlined, color: activeTheme.accent),
                title: const Text('Export Backup Archive', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                subtitle: const Text('Save all notes as a compressed .zip (.txt / .pdf)', style: TextStyle(color: AppColors.amoledTextSecondary, fontSize: 13)),
                onTap: () async {
                  final format = await ExportChoiceDialog.show(
                    context,
                    title: 'Export Backup Archive',
                    subtitle: 'Choose format to save all ${libraryState.notes.length} notes inside the .zip',
                    confirmLabel: 'Create Backup',
                    initialFormat: ExportFormat.txt,
                  );
                  if (format != null && context.mounted) {
                    await NoteExportService.exportNotesBackupArchive(
                      context,
                      libraryState.notes,
                      format: format,
                    );
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 5. About & Updates Section
          _buildSectionHeader('About & Updates', activeTheme.accent),
          _buildCard(
            activeTheme: activeTheme,
            children: [
              ListTile(
                title: const Text('wznotes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                subtitle: const Text('Pure AMOLED Keyboard-First Engine', style: TextStyle(color: AppColors.amoledTextSecondary, fontSize: 13)),
                trailing: Text('v${UpdateService.currentVersion}', style: const TextStyle(color: Colors.white38, fontSize: 14)),
              ),
              Divider(color: activeTheme.border, height: 1),
              Consumer(
                builder: (context, ref, _) {
                  final updateState = ref.watch(updateProvider);
                  final updateNotifier = ref.read(updateProvider.notifier);

                  return ListTile(
                    leading: Icon(Icons.system_update_alt_rounded, color: activeTheme.accent),
                    title: const Text('Check for Updates', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      updateState.hasUpdate
                          ? 'Update available: v${updateState.updateInfo!.version}'
                          : 'Current version: v${UpdateService.currentVersion}+${UpdateService.currentBuildNumber}',
                      style: TextStyle(
                        color: updateState.hasUpdate ? activeTheme.accent : AppColors.amoledTextSecondary,
                        fontSize: 13,
                        fontWeight: updateState.hasUpdate ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: updateState.isChecking
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: activeTheme.accent),
                          )
                        : (updateState.hasUpdate
                            ? Icon(Icons.arrow_circle_up_rounded, color: activeTheme.accent)
                            : const Icon(Icons.refresh_rounded, color: Colors.white54)),
                    onTap: updateState.isChecking
                        ? null
                        : () async {
                            if (updateState.hasUpdate) {
                              UpdateDialog.show(context, updateInfo: updateState.updateInfo!);
                            } else {
                              TopIslandToast.show(
                                context,
                                message: 'Checking for updates...',
                                isLoading: true,
                                color: activeTheme.accent,
                                duration: const Duration(seconds: 10),
                              );
                              await updateNotifier.check(silent: false);
                              final latest = ref.read(updateProvider);
                              if (context.mounted) {
                                TopIslandToast.dismiss();
                                if (latest.hasUpdate) {
                                  UpdateDialog.show(context, updateInfo: latest.updateInfo!);
                                } else if (latest.errorMessage != null) {
                                  TopIslandToast.show(
                                    context,
                                    message: 'Update check error: ${latest.errorMessage}',
                                    icon: Icons.error_outline_rounded,
                                    color: AppColors.accentRose,
                                  );
                                } else {
                                  TopIslandToast.show(
                                    context,
                                    message: 'wznotes is up to date (v${UpdateService.currentVersion}+${UpdateService.currentBuildNumber})',
                                    icon: Icons.check_circle_outline_rounded,
                                    color: AppColors.accentEmerald,
                                  );
                                }
                              }
                            }
                          },
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, [Color accentColor = AppColors.samsungOrange]) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: accentColor,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildCard({required AppThemePalette activeTheme, required List<Widget> children}) {
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
            splashColor: Colors.white10,
            highlightColor: Colors.transparent,
            splashFactory: InkRipple.splashFactory,
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}
