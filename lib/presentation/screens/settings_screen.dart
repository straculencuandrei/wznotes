import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../controllers/settings_controller.dart';
import '../controllers/notes_library_controller.dart';
import '../../infrastructure/security/biometric_service.dart';
import '../../infrastructure/update/update_service.dart';
import '../controllers/update_controller.dart';
import '../widgets/update_dialog.dart';
import '../widgets/top_island_toast.dart';
import 'sync_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final libraryState = ref.watch(notesLibraryProvider);

    return Scaffold(
      backgroundColor: AppColors.amoledBlack,
      appBar: AppBar(
        backgroundColor: AppColors.amoledBlack,
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
          // 1. Security & PIN Section
          _buildSectionHeader('Security & PIN'),
          _buildCard([
            if (Platform.isAndroid || Platform.isIOS) ...[
              SwitchListTile(
                activeColor: AppColors.samsungOrange,
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
              const Divider(color: AppColors.amoledBorder, height: 1),
            ],
            ListTile(
              leading: const Icon(Icons.pin_rounded, color: AppColors.samsungOrange),
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
          ]),

          const SizedBox(height: 24),

          // 2. Editor & Writing Preferences
          _buildSectionHeader('Writing & Editor'),
          _buildCard([
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
                  Text('${settings.fontSize.toInt()}', style: const TextStyle(color: AppColors.samsungOrange, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.white70),
                    onPressed: settings.fontSize < 25 ? () => settingsNotifier.setFontSize(settings.fontSize + 2) : null,
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.amoledBorder, height: 1),
            SwitchListTile(
              activeColor: AppColors.samsungOrange,
              title: const Text('VSCode Smooth Caret Effect', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              subtitle: const Text('Smooth animated typing cursor', style: TextStyle(color: AppColors.amoledTextSecondary, fontSize: 13)),
              value: settings.smoothCaretEnabled,
              onChanged: (val) => settingsNotifier.toggleSmoothCaret(val),
            ),
            const Divider(color: AppColors.amoledBorder, height: 1),
            SwitchListTile(
              activeColor: AppColors.samsungOrange,
              title: const Text('Show Word Count', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              subtitle: const Text('Display real-time word counter in note header', style: TextStyle(color: AppColors.amoledTextSecondary, fontSize: 13)),
              value: settings.showWordCount,
              onChanged: (val) => settingsNotifier.toggleWordCount(val),
            ),
          ]),

          const SizedBox(height: 24),

          // 3. Storage & Backup
          _buildSectionHeader('Storage & Sync'),
          _buildCard([
            ListTile(
              title: const Text('Total Notes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              trailing: Text('${libraryState.notes.length}', style: const TextStyle(color: AppColors.samsungOrange, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const Divider(color: AppColors.amoledBorder, height: 1),
            ListTile(
              leading: const Icon(Icons.sync_alt_rounded, color: AppColors.samsungOrange),
              title: const Text('Wi-Fi Device Sync', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              subtitle: const Text('Sync notes between Phone & PC over local network', style: TextStyle(color: AppColors.amoledTextSecondary, fontSize: 13)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white54),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const SyncScreen()),
                );
              },
            ),
            const Divider(color: AppColors.amoledBorder, height: 1),
            ListTile(
              leading: const Icon(Icons.folder_zip_outlined, color: AppColors.samsungOrange),
              title: const Text('Export Backup Archive', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              subtitle: const Text('Save all notes as a compressed .zip container', style: TextStyle(color: AppColors.amoledTextSecondary, fontSize: 13)),
              onTap: () {
                TopIslandToast.show(
                  context,
                  message: 'Backup archive created with ${libraryState.notes.length} notes!',
                  icon: Icons.check_circle_outline_rounded,
                  color: AppColors.accentEmerald,
                );
              },
            ),
          ]),

          const SizedBox(height: 24),

          // 4. About & Updates Section
          _buildSectionHeader('About & Updates'),
          _buildCard([
            ListTile(
              title: const Text('wznotes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              subtitle: const Text('Pure AMOLED Keyboard-First Engine', style: TextStyle(color: AppColors.amoledTextSecondary, fontSize: 13)),
              trailing: Text('v${UpdateService.currentVersion}', style: const TextStyle(color: Colors.white38, fontSize: 14)),
            ),
            const Divider(color: AppColors.amoledBorder, height: 1),
            Consumer(
              builder: (context, ref, _) {
                final updateState = ref.watch(updateProvider);
                final updateNotifier = ref.read(updateProvider.notifier);

                return ListTile(
                  leading: const Icon(Icons.system_update_alt_rounded, color: AppColors.samsungOrange),
                  title: const Text('Check for Updates', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    updateState.hasUpdate
                        ? 'Update available: v${updateState.updateInfo!.version}'
                        : 'Current version: v${UpdateService.currentVersion}+${UpdateService.currentBuildNumber}',
                    style: TextStyle(
                      color: updateState.hasUpdate ? AppColors.samsungOrange : AppColors.amoledTextSecondary,
                      fontSize: 13,
                      fontWeight: updateState.hasUpdate ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: updateState.isChecking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.samsungOrange),
                        )
                      : (updateState.hasUpdate
                          ? const Icon(Icons.arrow_circle_up_rounded, color: AppColors.samsungOrange)
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
                              color: AppColors.samsungOrange,
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
          ]),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.samsungOrange,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.amoledSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.amoledBorder, width: 1.2),
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
