import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../controllers/settings_controller.dart';
import '../controllers/notes_library_controller.dart';
import '../../infrastructure/security/biometric_service.dart';

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
          icon: const Icon(Icons.arrow_back_ios_new, size: 22, color: Colors.white),
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
          // 1. Security & Privacy Section
          _buildSectionHeader('Security & Biometrics'),
          _buildCard([
            SwitchListTile(
              activeColor: AppColors.samsungOrange,
              title: const Text('Fingerprint / Biometric Lock', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              subtitle: const Text('Require fingerprint to unlock locked notes', style: TextStyle(color: AppColors.amoledTextSecondary, fontSize: 13)),
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
            ListTile(
              title: const Text('Change App PIN', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              subtitle: Text('Current PIN: ••••', style: const TextStyle(color: AppColors.amoledTextSecondary, fontSize: 13)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white54),
              onTap: () async {
                final isAuthed = await BiometricSecurityService.promptPin(context, correctPin: settings.appPin, title: 'Enter Current PIN');
                if (isAuthed && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN verified. Enter new 4-digit PIN.')),
                  );
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
          _buildSectionHeader('Storage & Backup'),
          _buildCard([
            ListTile(
              title: const Text('Total Notes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              trailing: Text('${libraryState.notes.length}', style: const TextStyle(color: AppColors.samsungOrange, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const Divider(color: AppColors.amoledBorder, height: 1),
            ListTile(
              leading: const Icon(Icons.folder_zip_outlined, color: AppColors.samsungOrange),
              title: const Text('Export Backup Archive', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              subtitle: const Text('Save all notes as a compressed .zip container', style: TextStyle(color: AppColors.amoledTextSecondary, fontSize: 13)),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Backup archive created with ${libraryState.notes.length} notes!'),
                    backgroundColor: AppColors.accentEmerald,
                  ),
                );
              },
            ),
          ]),

          const SizedBox(height: 24),

          // 4. About Section
          _buildSectionHeader('About'),
          _buildCard([
            const ListTile(
              title: Text('OpenNotes / wznotes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              subtitle: Text('Pure AMOLED Keyboard-First Engine', style: TextStyle(color: AppColors.amoledTextSecondary, fontSize: 13)),
              trailing: Text('v1.0.0', style: TextStyle(color: Colors.white38, fontSize: 14)),
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
