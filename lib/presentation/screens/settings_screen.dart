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
import 'theme_selection_screen.dart';

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
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: activeTheme.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Settings',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: activeTheme.textPrimary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        physics: const BouncingScrollPhysics(),
        children: [
          // 1. Appearance & Themes Section
          _buildSectionHeader('Appearance & Themes', activeTheme.accent),
          _buildCard(
            activeTheme: activeTheme,
            children: [
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: activeTheme.surfaceElevated,
                    shape: BoxShape.circle,
                    border: Border.all(color: activeTheme.accent, width: 1.8),
                  ),
                  child: Center(
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: activeTheme.accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: activeTheme.accent.withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                title: Text(
                  'Theme & Palette',
                  style: TextStyle(color: activeTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${activeTheme.name} (${AppThemes.allThemes.length} curated palettes)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: activeTheme.textSecondary, fontSize: 13),
                ),
                trailing: Icon(Icons.chevron_right, color: activeTheme.textSecondary),
                onTap: () {
                  Navigator.of(context).push(
                    PageRouteBuilder<void>(
                      pageBuilder: (_, animation, __) => const ThemeSelectionScreen(),
                      transitionsBuilder: (_, animation, __, child) => FadeTransition(
                        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                        child: child,
                      ),
                      transitionDuration: const Duration(milliseconds: 140),
                    ),
                  );
                },
              ),
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
                  title: Text('Fingerprint / Face Unlock', style: TextStyle(color: activeTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                  subtitle: Text('Require biometrics to open locked notes', style: TextStyle(color: activeTheme.textSecondary, fontSize: 13)),
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
                title: Text('Set / Change Master PIN', style: TextStyle(color: activeTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  settings.appPin == '1234'
                      ? 'Default PIN: 1234 (Tap to set custom PIN)'
                      : 'Custom PIN active (••••)',
                  style: TextStyle(color: activeTheme.textSecondary, fontSize: 13),
                ),
                trailing: Icon(Icons.chevron_right, color: activeTheme.textSecondary),
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
                title: Text('Editor Font Size', style: TextStyle(color: activeTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                subtitle: Text('${settings.fontSize.toInt()}sp (Default)', style: TextStyle(color: activeTheme.textSecondary, fontSize: 13)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove, color: activeTheme.textPrimary),
                      onPressed: settings.fontSize > 13 ? () => settingsNotifier.setFontSize(settings.fontSize - 2) : null,
                    ),
                    Text('${settings.fontSize.toInt()}', style: TextStyle(color: activeTheme.accent, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: Icon(Icons.add, color: activeTheme.textPrimary),
                      onPressed: settings.fontSize < 25 ? () => settingsNotifier.setFontSize(settings.fontSize + 2) : null,
                    ),
                  ],
                ),
              ),
              Divider(color: activeTheme.border, height: 1),
              SwitchListTile(
                activeThumbColor: activeTheme.accent,
                title: Text('VSCode Smooth Caret Effect', style: TextStyle(color: activeTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                subtitle: Text('Smooth animated typing cursor', style: TextStyle(color: activeTheme.textSecondary, fontSize: 13)),
                value: settings.smoothCaretEnabled,
                onChanged: (val) => settingsNotifier.toggleSmoothCaret(val),
              ),
              Divider(color: activeTheme.border, height: 1),
              SwitchListTile(
                activeThumbColor: activeTheme.accent,
                title: Text('Show Word Count', style: TextStyle(color: activeTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                subtitle: Text('Display real-time word counter in note header & library', style: TextStyle(color: activeTheme.textSecondary, fontSize: 13)),
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
                title: Text('Total Notes', style: TextStyle(color: activeTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                trailing: Text('${libraryState.notes.length}', style: TextStyle(color: activeTheme.accent, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              Divider(color: activeTheme.border, height: 1),
              ListTile(
                leading: Icon(Icons.sync_alt_rounded, color: activeTheme.accent),
                title: Text('Wi-Fi Device Sync', style: TextStyle(color: activeTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                subtitle: Text('Sync notes between Phone & PC over local network', style: TextStyle(color: activeTheme.textSecondary, fontSize: 13)),
                trailing: Icon(Icons.chevron_right, color: activeTheme.textSecondary),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const SyncScreen()),
                  );
                },
              ),
              Divider(color: activeTheme.border, height: 1),
              ListTile(
                leading: Icon(Icons.folder_zip_outlined, color: activeTheme.accent),
                title: Text('Export Backup Archive', style: TextStyle(color: activeTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                subtitle: Text('Save all notes as a compressed .zip (.txt / .pdf)', style: TextStyle(color: activeTheme.textSecondary, fontSize: 13)),
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
                title: Text('wznotes', style: TextStyle(color: activeTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                subtitle: Text('Personal Notes & Inking Engine', style: TextStyle(color: activeTheme.textSecondary, fontSize: 13)),
                trailing: Text('v${UpdateService.currentVersion}', style: TextStyle(color: activeTheme.textSecondary, fontSize: 14)),
              ),
              Divider(color: activeTheme.border, height: 1),
              Consumer(
                builder: (context, ref, _) {
                  final updateState = ref.watch(updateProvider);
                  final updateNotifier = ref.read(updateProvider.notifier);

                  return ListTile(
                    leading: Icon(Icons.system_update_alt_rounded, color: activeTheme.accent),
                    title: Text('Check for Updates', style: TextStyle(color: activeTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      updateState.hasUpdate
                          ? 'Update available: v${updateState.updateInfo!.version}'
                          : 'Current version: v${UpdateService.currentVersion}+${UpdateService.currentBuildNumber}',
                      style: TextStyle(
                        color: updateState.hasUpdate ? activeTheme.accent : activeTheme.textSecondary,
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
                            : Icon(Icons.refresh_rounded, color: activeTheme.textSecondary)),
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

  Widget _buildSectionHeader(String title, Color accentColor) {
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
