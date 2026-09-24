import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_themes.dart';
import '../../domain/models/note_document.dart';
import '../controllers/notes_library_controller.dart';
import '../controllers/document_controller.dart';
import '../controllers/settings_controller.dart';
import '../../infrastructure/security/biometric_service.dart';
import '../controllers/update_controller.dart';
import '../widgets/update_dialog.dart';
import '../widgets/hold_to_select_border_card.dart';
import '../widgets/top_island_toast.dart';
import '../widgets/export_dialog.dart';
import 'note_editor_screen.dart';
import 'settings_screen.dart';
import 'sync_screen.dart';

/// Pure AMOLED Samsung Notes Inspired Home Library Screen
class NotesLibraryScreen extends ConsumerWidget {
  const NotesLibraryScreen({super.key});

  Future<void> _handleNoteTap(BuildContext context, WidgetRef ref, NoteDocument note) async {
    if (note.metadata.isDeleted) {
      _showTrashNoteDialog(context, ref, note);
      return;
    }

    if (note.metadata.isLocked) {
      final settings = ref.read(settingsProvider);
      bool isUnlocked = false;

      // 1. Google fingerprint pop-up on mobile if biometrics is enabled in settings
      if ((Platform.isAndroid || Platform.isIOS) && settings.isBiometricEnabled) {
        isUnlocked = await BiometricSecurityService.authenticate(
          reason: 'Scan fingerprint to unlock "${note.metadata.title}"',
        );
      }

      // 2. PIN Entry dialog (PC goes directly here; mobile falls back here if fingerprint cancelled/fails)
      if (!isUnlocked && context.mounted) {
        final pinToMatch = (note.metadata.lockPin != null && note.metadata.lockPin!.isNotEmpty)
            ? note.metadata.lockPin!
            : settings.appPin;

        isUnlocked = await BiometricSecurityService.promptPin(
          context,
          correctPin: pinToMatch,
          title: 'Unlock Note',
          subtitle: 'Enter 4-digit PIN to open "${note.metadata.title}"',
        );
      }

      if (!isUnlocked) return;
    }

    if (!context.mounted) return;
    _openNote(context, ref, note);
  }

  void _openNote(BuildContext context, WidgetRef ref, NoteDocument note) {
    ref.read(documentProvider.notifier).setDocument(note);
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => const NoteEditorScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 140),
        reverseTransitionDuration: const Duration(milliseconds: 110),
      ),
    );
  }

  void _confirmPermanentDeleteSingle(BuildContext context, WidgetRef ref, NoteDocument note) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF2E2E2E)),
        ),
        title: const Text('Delete Permanently?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Permanently delete "${note.metadata.title.isNotEmpty ? note.metadata.title : 'this note'}"? This action cannot be undone.',
          style: const TextStyle(color: AppColors.amoledTextSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(notesLibraryProvider.notifier).permanentlyDeleteNote(note.metadata.id);
              TopIslandToast.show(
                context,
                message: 'Note permanently deleted',
                icon: Icons.delete_forever_rounded,
                color: AppColors.accentRose,
              );
            },
            child: const Text('Delete Forever', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmEmptyTrash(BuildContext context, WidgetRef ref, int count) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF2E2E2E)),
        ),
        title: const Text('Empty Trash?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Permanently delete all $count ${count == 1 ? 'note' : 'notes'} in Trash? This action cannot be undone.',
          style: const TextStyle(color: AppColors.amoledTextSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(notesLibraryProvider.notifier).emptyTrash();
              TopIslandToast.show(
                context,
                message: 'Trash emptied',
                icon: Icons.delete_sweep_rounded,
                color: AppColors.accentRose,
              );
            },
            child: const Text('Empty Trash', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showTrashNoteDialog(BuildContext context, WidgetRef ref, NoteDocument note) {
    final daysLeft = note.metadata.daysUntilPermanentDeletion;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF2E2E2E)),
        ),
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: AppColors.accentRose, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                note.metadata.title.isNotEmpty ? note.metadata.title : 'Deleted Note',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          'This note is currently in Trash ($daysLeft days until automatic permanent deletion).\n\nRestore this note to view and edit it.',
          style: const TextStyle(color: AppColors.amoledTextSecondary, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _confirmPermanentDeleteSingle(context, ref, note);
            },
            child: const Text('Delete Forever', style: TextStyle(color: AppColors.accentRose)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentEmerald,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.restore_rounded, size: 18),
            label: const Text('Restore Note', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(notesLibraryProvider.notifier).restoreNote(note.metadata.id);
              TopIslandToast.show(
                context,
                message: '"${note.metadata.title.isNotEmpty ? note.metadata.title : 'Note'}" restored',
                icon: Icons.restore_rounded,
                color: AppColors.accentEmerald,
              );
            },
          ),
        ],
      ),
    );
  }

  void _showNoteActions(BuildContext context, WidgetRef ref, NoteDocument note) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      barrierColor: Colors.black54,
      isScrollControlled: true,
      builder: (context) {
        final isFav = note.metadata.folderId == 'favorites';
        final isLocked = note.metadata.isLocked;
        final title = note.metadata.title.isNotEmpty ? note.metadata.title : 'Untitled Note';

        return Container(
          margin: const EdgeInsets.only(left: 14, right: 14, bottom: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF282828), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header: Title + Word count & Date pill
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Builder(
                        builder: (context) {
                          final showWordCount = ref.watch(settingsProvider.select((s) => s.showWordCount));
                          final wordCountPart = (showWordCount && note.metadata.wordCount > 0)
                              ? '${note.metadata.wordCount}w • '
                              : '';
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF222222),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              note.metadata.isDeleted
                                  ? '${note.metadata.daysUntilPermanentDeletion}d left in Trash'
                                  : '$wordCountPart${_formatDate(note.metadata.modifiedAt)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: note.metadata.isDeleted ? AppColors.accentRose : const Color(0xFF999999),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFF262626), height: 1),
                  const SizedBox(height: 8),

                  if (note.metadata.isDeleted) ...[
                    // Trash actions: Restore or Delete Forever
                    _buildCompactActionRow(
                      icon: Icons.restore_rounded,
                      iconColor: AppColors.accentEmerald,
                      iconBg: AppColors.accentEmerald.withValues(alpha: 0.15),
                      title: 'Restore note',
                      subtitle: 'Move back to active notes',
                      onTap: () {
                        ref.read(notesLibraryProvider.notifier).restoreNote(note.metadata.id);
                        Navigator.of(context).pop();
                        TopIslandToast.show(
                          context,
                          message: '"$title" restored',
                          icon: Icons.restore_rounded,
                          color: AppColors.accentEmerald,
                        );
                      },
                    ),
                    _buildCompactActionRow(
                      icon: Icons.delete_forever_rounded,
                      iconColor: AppColors.accentRose,
                      iconBg: AppColors.accentRose.withValues(alpha: 0.15),
                      title: 'Delete permanently',
                      subtitle: 'Cannot be undone',
                      titleColor: AppColors.accentRose,
                      onTap: () {
                        Navigator.of(context).pop();
                        _confirmPermanentDeleteSingle(context, ref, note);
                      },
                    ),
                  ] else ...[
                    // Compact Action Rows
                    // 1. Select Multiple Notes
                  _buildCompactActionRow(
                    icon: Icons.checklist_rounded,
                    iconColor: Colors.white,
                    iconBg: const Color(0xFF2E2E2E),
                    title: 'Select multiple notes',
                    subtitle: 'Enter multi-selection mode',
                    onTap: () {
                      Navigator.of(context).pop();
                      ref.read(notesLibraryProvider.notifier).toggleNoteSelection(note.metadata.id);
                    },
                  ),

                  // 2. Lock / Unlock
                  _buildCompactActionRow(
                    icon: isLocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                    iconColor: AppColors.samsungOrange,
                    iconBg: AppColors.samsungOrange.withValues(alpha: 0.15),
                    title: isLocked ? 'Unlock note' : 'Lock note with Fingerprint / PIN',
                    subtitle: isLocked ? 'Remove security protection' : 'Protects note with fingerprint & PIN',
                    onTap: () async {
                      Navigator.of(context).pop();
                      if (!isLocked) {
                        final currentAppPin = ref.read(settingsProvider).appPin;
                        final updated = note.copyWith(
                          metadata: note.metadata.copyWith(
                            isLocked: true,
                            lockPin: currentAppPin,
                            modifiedAt: DateTime.now(),
                          ),
                        );
                        ref.read(notesLibraryProvider.notifier).saveNote(updated);
                        if (context.mounted) {
                          TopIslandToast.show(
                            context,
                            message: 'Note locked with Fingerprint & PIN',
                            icon: Icons.lock_outline_rounded,
                            color: AppColors.accentEmerald,
                          );
                        }
                      } else {
                        // Allow bottom sheet pop animation to finish cleanly before showing auth
                        await Future<void>.delayed(const Duration(milliseconds: 150));
                        if (!context.mounted) return;

                        final settings = ref.read(settingsProvider);
                        bool isAuthed = false;

                        if ((Platform.isAndroid || Platform.isIOS) && settings.isBiometricEnabled) {
                          isAuthed = await BiometricSecurityService.authenticate(
                            reason: 'Scan fingerprint to unlock "${note.metadata.title}"',
                          );
                        }

                        if (!isAuthed && context.mounted) {
                          final pinToMatch = (note.metadata.lockPin != null && note.metadata.lockPin!.isNotEmpty)
                              ? note.metadata.lockPin!
                              : settings.appPin;

                          isAuthed = await BiometricSecurityService.promptPin(
                            context,
                            correctPin: pinToMatch,
                            title: 'Unlock Note',
                            subtitle: 'Enter PIN or scan fingerprint',
                          );
                        }

                        if (isAuthed) {
                          final updated = note.copyWith(
                            metadata: note.metadata.copyWith(
                              isLocked: false,
                              clearLockPin: true,
                              modifiedAt: DateTime.now(),
                            ),
                          );
                          ref.read(notesLibraryProvider.notifier).saveNote(updated);
                          if (context.mounted) {
                            TopIslandToast.show(
                              context,
                              message: 'Note unlocked',
                              icon: Icons.lock_open_rounded,
                              color: AppColors.accentEmerald,
                            );
                          }
                        }
                      }
                    },
                  ),

                  // 3. Favorite
                  _buildCompactActionRow(
                    icon: isFav ? Icons.star_rounded : Icons.star_border_rounded,
                    iconColor: const Color(0xFFFBBF24),
                    iconBg: const Color(0xFFFBBF24).withValues(alpha: 0.15),
                    title: isFav ? 'Remove from favorites' : 'Add to favorites',
                    onTap: () {
                      ref.read(notesLibraryProvider.notifier).toggleFavorite(note.metadata.id);
                      Navigator.of(context).pop();
                    },
                  ),

                  // 4. Export (.txt / .pdf)
                  _buildCompactActionRow(
                    icon: Icons.file_download_outlined,
                    iconColor: const Color(0xFF38BDF8),
                    iconBg: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                    title: 'Export note (.txt / .pdf)',
                    subtitle: 'Save as text or print-ready PDF',
                    onTap: () async {
                      Navigator.of(context).pop();
                      final format = await ExportChoiceDialog.show(
                        context,
                        title: 'Export Note',
                        subtitle: 'Choose format for "${note.metadata.title}"',
                        confirmLabel: 'Export',
                        initialFormat: ExportFormat.txt,
                      );
                      if (format != null && context.mounted) {
                        await NoteExportService.exportSingleNote(
                          context,
                          note,
                          format: format,
                        );
                      }
                    },
                  ),

                  // 5. Move to Trash
                  _buildCompactActionRow(
                    icon: Icons.delete_outline_rounded,
                    iconColor: AppColors.accentRose,
                    iconBg: AppColors.accentRose.withValues(alpha: 0.15),
                    title: 'Move to Trash',
                    subtitle: 'Can be restored within 30 days',
                    titleColor: AppColors.accentRose,
                    onTap: () {
                      ref.read(notesLibraryProvider.notifier).deleteNote(note.metadata.id);
                      Navigator.of(context).pop();
                      TopIslandToast.show(
                        context,
                        message: 'Note moved to Trash',
                        icon: Icons.delete_outline_rounded,
                        color: AppColors.accentRose,
                      );
                    },
                  ),
                ],
              ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _buildCompactActionRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    String? subtitle,
    Color titleColor = Colors.white,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 9.0),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF777777)),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF444444), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(notesLibraryProvider);
    final libraryNotifier = ref.read(notesLibraryProvider.notifier);
    final notes = libraryState.filteredNotes;
    final activeTheme = ref.watch(appThemeProvider);
    final isTrash = libraryState.selectedCategory == 'Trash';

    final screenWidth = MediaQuery.of(context).size.width;
    final gridColumns = screenWidth > 1200 ? 5 : (screenWidth > 900 ? 4 : (screenWidth > 600 ? 3 : 2));

    final isSelectionMode = libraryState.isSelectionMode;
    final selectedCount = libraryState.selectedNoteIds.length;
    final isAllSelected = selectedCount == notes.length && notes.isNotEmpty;

    return PopScope(
      canPop: !isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && isSelectionMode) {
          libraryNotifier.clearSelection();
        }
      },
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
            if (!isSelectionMode) {
              final newDoc = ref.read(notesLibraryProvider.notifier).createNewNote();
              _openNote(context, ref, newDoc);
            }
          },
          const SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true): () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SyncScreen()),
            );
          },
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: activeTheme.background,
body: Stack(
              children: [
                SafeArea(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // 1. Large Samsung One UI Header (or Selection Mode Header)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 24, right: 16, top: 20, bottom: 8),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                            child: isSelectionMode
                                ? Container(
                                    key: const ValueKey('selection_header'),
                                    height: 64,
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                                              tooltip: 'Close Selection',
                                              onPressed: () => libraryNotifier.clearSelection(),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '$selectedCount Selected',
                                              style: const TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.amoledTextPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        TextButton.icon(
                                          style: TextButton.styleFrom(
                                            foregroundColor: AppColors.samsungOrange,
                                          ),
                                          icon: Icon(isAllSelected ? Icons.deselect_rounded : Icons.select_all_rounded, size: 20),
                                          label: Text(
                                            isAllSelected ? 'Deselect All' : 'Select All',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          onPressed: () {
                                            if (isAllSelected) {
                                              libraryNotifier.clearSelection();
                                            } else {
                                              libraryNotifier.selectAllNotes();
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  )
                                : Container(
                                    key: const ValueKey('normal_header'),
                                    height: 64,
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              isTrash
                                                  ? 'Trash'
                                                  : (libraryState.selectedCategory == 'Favorites' ? 'Favorites' : 'All notes'),
                                              style: TextStyle(
                                                fontSize: 28,
                                                fontWeight: FontWeight.w900,
                                                color: activeTheme.textPrimary,
                                                letterSpacing: -0.8,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              isTrash
                                                  ? '${notes.length} deleted • 30-day auto-purge'
                                                  : '${notes.length} ${notes.length == 1 ? 'note' : 'notes'}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: isTrash ? AppColors.accentRose : activeTheme.textSecondary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            if (isTrash) ...[
                                              if (notes.isNotEmpty)
                                                TextButton.icon(
                                                  style: TextButton.styleFrom(
                                                    foregroundColor: AppColors.accentRose,
                                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                                  ),
                                                  icon: const Icon(Icons.delete_sweep_rounded, size: 20),
                                                  label: const Text('Empty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                  onPressed: () => _confirmEmptyTrash(context, ref, notes.length),
                                                ),
                                            ] else ...[
                                              IconButton(
                                                icon: Icon(Icons.sync_alt_rounded, color: activeTheme.accent, size: 24),
                                                tooltip: 'Wi-Fi Device Sync (Ctrl+Shift+S)',
                                                onPressed: () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute<void>(builder: (_) => const SyncScreen()),
                                                  );
                                                },
                                              ),
                                            ],
                                            IconButton(
                                              icon: Icon(
                                                libraryState.isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                                                color: activeTheme.textPrimary,
                                                size: 24,
                                              ),
                                              tooltip: libraryState.isGridView ? 'List View' : 'Grid View',
                                              onPressed: () => libraryNotifier.toggleViewLayout(),
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.settings_outlined, color: activeTheme.textPrimary, size: 24),
                                              tooltip: 'Settings',
                                              onPressed: () {
                                                Navigator.of(context).push(
                                                  MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                      ),

                      // 1.5. In-App Update Alert Banner (if update available)
                      Consumer(
                        builder: (context, ref, _) {
                          final updateState = ref.watch(updateProvider);
                          if (!updateState.hasUpdate) return const SliverToBoxAdapter(child: SizedBox.shrink());

                          final info = updateState.updateInfo!;
                          return SliverToBoxAdapter(
                            child: AnimatedOpacity(
                              opacity: isSelectionMode ? 0.3 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: IgnorePointer(
                                ignoring: isSelectionMode,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF1E1710), Color(0xFF261D12)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: AppColors.samsungOrange.withValues(alpha: 0.7)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.rocket_launch_rounded, color: AppColors.samsungOrange, size: 24),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'wznotes v${info.version} Available',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              const Text(
                                                'Tap to view what\'s new & update',
                                                style: TextStyle(color: AppColors.amoledTextSecondary, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.samsungOrange,
                                            foregroundColor: Colors.black,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          onPressed: () {
                                            UpdateDialog.show(context, updateInfo: info);
                                          },
                                          child: const Text('Update', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                        ),
                                        const SizedBox(width: 6),
                                        IconButton(
                                          icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white54),
                                          tooltip: 'Dismiss',
                                          onPressed: () => ref.read(updateProvider.notifier).dismiss(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      // 2. AMOLED Search Bar with dynamic Theme
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                          child: AnimatedOpacity(
                            opacity: isSelectionMode ? 0.35 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: IgnorePointer(
                              ignoring: isSelectionMode,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: activeTheme.surface,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: activeTheme.border, width: 1.2),
                                ),
                                child: TextField(
                                  style: TextStyle(fontSize: 16, color: activeTheme.textPrimary),
                                  decoration: InputDecoration(
                                    hintText: 'Search notes...',
                                    hintStyle: const TextStyle(color: Color(0xFF666666), fontSize: 15),
                                    prefixIcon: Icon(Icons.search, color: activeTheme.accent, size: 24),
                                    suffixIcon: libraryState.searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 20, color: Colors.white54),
                                            onPressed: () => libraryNotifier.setSearchQuery(''),
                                          )
                                        : null,
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  onChanged: (val) => libraryNotifier.setSearchQuery(val),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 2.5. Category Navigation Chips (All, Favorites, Trash)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 20, right: 20, top: 4, bottom: 8),
                          child: AnimatedOpacity(
                            opacity: isSelectionMode ? 0.35 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: IgnorePointer(
                              ignoring: isSelectionMode,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Row(
                                  children: [
                                    _buildCategoryChip(
                                      label: 'All Notes',
                                      count: libraryState.activeNotesCount,
                                      isSelected: libraryState.selectedCategory == 'All',
                                      activeTheme: activeTheme,
                                      onTap: () => libraryNotifier.setSelectedCategory('All'),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildCategoryChip(
                                      label: 'Favorites',
                                      icon: Icons.star_rounded,
                                      count: libraryState.favoritesCount,
                                      isSelected: libraryState.selectedCategory == 'Favorites',
                                      activeTheme: activeTheme,
                                      onTap: () => libraryNotifier.setSelectedCategory('Favorites'),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildCategoryChip(
                                      label: 'Trash',
                                      icon: Icons.delete_outline_rounded,
                                      count: libraryState.trashCount,
                                      isSelected: libraryState.selectedCategory == 'Trash',
                                      activeTheme: activeTheme,
                                      onTap: () => libraryNotifier.setSelectedCategory('Trash'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 3. Notes Content
                      if (notes.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildEmptyState(context, ref),
                        )
                      else if (libraryState.isGridView)
                        SliverPadding(
                          padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 120),
                          sliver: SliverGrid(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: gridColumns,
                              childAspectRatio: 0.85,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildGridCard(context, ref, notes[index], libraryState),
                              childCount: notes.length,
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 120),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildListCard(context, ref, notes[index], libraryState),
                              childCount: notes.length,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Floating AMOLED Batch Action Toolbar (Smooth slide up and fade in)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    ignoring: !isSelectionMode,
                    child: AnimatedSlide(
                      offset: isSelectionMode ? Offset.zero : const Offset(0.0, 1.4),
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      child: AnimatedOpacity(
                        opacity: isSelectionMode ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        child: _buildBatchActionBar(context, ref, libraryState),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Floating Action Button (Smooth scale and fade, hidden in selection mode or trash)
            floatingActionButton: AnimatedScale(
              scale: (isSelectionMode || isTrash) ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: AnimatedOpacity(
                opacity: (isSelectionMode || isTrash) ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 180),
                child: IgnorePointer(
                  ignoring: isSelectionMode || isTrash,
                  child: FloatingActionButton.extended(
                    backgroundColor: activeTheme.accent,
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    icon: const Icon(Icons.edit, color: Colors.black, size: 24),
                    label: const Text(
                      'Write',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    onPressed: () {
                      final newDoc = ref.read(notesLibraryProvider.notifier).createNewNote();
                      _openNote(context, ref, newDoc);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- BATCH ACTION BAR & DIALOGS ---

  Widget _buildBatchActionBar(BuildContext context, WidgetRef ref, NotesLibraryState state) {
    final selectedCount = state.selectedNoteIds.length;
    final isTrash = state.selectedCategory == 'Trash';
    final activeTheme = ref.watch(appThemeProvider);

    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 18),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: activeTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: activeTheme.accent.withValues(alpha: 0.6), width: 1.3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isTrash) ...[
                // Restore Selected
                IconButton(
                  icon: const Icon(Icons.restore_rounded, color: AppColors.accentEmerald, size: 24),
                  tooltip: 'Restore Selected',
                  onPressed: selectedCount == 0
                      ? null
                      : () {
                          ref.read(notesLibraryProvider.notifier).batchRestoreSelected();
                          TopIslandToast.show(
                            context,
                            message: '$selectedCount notes restored',
                            icon: Icons.restore_rounded,
                            color: AppColors.accentEmerald,
                          );
                        },
                ),

                // Delete Forever
                IconButton(
                  icon: const Icon(Icons.delete_forever_rounded, color: AppColors.accentRose, size: 23),
                  tooltip: 'Delete Forever',
                  onPressed: selectedCount == 0
                      ? null
                      : () => _showBatchDeleteDialog(context, ref, selectedCount),
                ),
              ] else ...[
                // Star / Favorite Toggle
                IconButton(
                  icon: const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 24),
                  tooltip: 'Add to Favorites',
                  onPressed: selectedCount == 0
                      ? null
                      : () {
                          ref.read(notesLibraryProvider.notifier).batchToggleFavorite(setAsFavorite: true);
                          TopIslandToast.show(
                            context,
                            message: '$selectedCount notes marked as favorite',
                            icon: Icons.star_rounded,
                            color: const Color(0xFFFBBF24),
                          );
                        },
                ),

                // Lock / Unlock
                IconButton(
                  icon: Icon(Icons.lock_outline_rounded, color: activeTheme.accent, size: 23),
                  tooltip: 'Lock / Unlock Notes',
                  onPressed: selectedCount == 0
                      ? null
                      : () => _handleBatchLock(context, ref, state),
                ),

                // Export Selected Notes (.txt / .pdf)
                IconButton(
                  icon: const Icon(Icons.file_download_outlined, color: Color(0xFF38BDF8), size: 23),
                  tooltip: 'Export Selected',
                  onPressed: selectedCount == 0
                      ? null
                      : () async {
                          final selectedNotes = state.notes.where((n) => state.selectedNoteIds.contains(n.metadata.id)).toList();
                          final format = await ExportChoiceDialog.show(
                            context,
                            title: 'Export Selected Notes',
                            subtitle: 'Create a backup archive with $selectedCount selected notes',
                            confirmLabel: 'Export Archive',
                            initialFormat: ExportFormat.txt,
                          );
                          if (format != null && context.mounted) {
                            await NoteExportService.exportNotesBackupArchive(
                              context,
                              selectedNotes,
                              format: format,
                            );
                          }
                        },
                ),

                // Move to Trash
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.accentRose, size: 23),
                  tooltip: 'Move to Trash',
                  onPressed: selectedCount == 0
                      ? null
                      : () => _showBatchDeleteDialog(context, ref, selectedCount),
                ),
              ],

              const SizedBox(width: 6),
              Container(width: 1, height: 24, color: const Color(0xFF333333)),
              const SizedBox(width: 6),

              // Close / Done
              IconButton(
                icon: const Icon(Icons.check_rounded, color: Colors.white, size: 23),
                tooltip: 'Done',
                onPressed: () => ref.read(notesLibraryProvider.notifier).clearSelection(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleBatchLock(BuildContext context, WidgetRef ref, NotesLibraryState state) async {
    final selectedNotes = state.notes.where((n) => state.selectedNoteIds.contains(n.metadata.id)).toList();
    if (selectedNotes.isEmpty) return;

    final hasUnlocked = selectedNotes.any((n) => !n.metadata.isLocked);
    final count = selectedNotes.length;

    if (hasUnlocked) {
      // Lock all selected notes directly with Fingerprint & PIN protection
      final currentAppPin = ref.read(settingsProvider).appPin;
      ref.read(notesLibraryProvider.notifier).batchSetLock(locked: true, lockPin: currentAppPin);
      if (context.mounted) {
        TopIslandToast.show(
          context,
          message: '$count notes locked with Fingerprint & PIN',
          icon: Icons.lock_outline_rounded,
          color: AppColors.accentEmerald,
        );
      }
    } else {
      // Unlock all selected notes: verify auth first
      final settings = ref.read(settingsProvider);
      bool isAuthed = false;

      if ((Platform.isAndroid || Platform.isIOS) && settings.isBiometricEnabled) {
        isAuthed = await BiometricSecurityService.authenticate(
          reason: 'Scan fingerprint to unlock $count notes',
        );
      }

      if (!isAuthed && context.mounted) {
        isAuthed = await BiometricSecurityService.promptPin(
          context,
          correctPin: settings.appPin,
          title: 'Unlock $count Notes',
          subtitle: 'Enter PIN to unlock selected notes',
        );
      }
      if (isAuthed) {
        ref.read(notesLibraryProvider.notifier).batchSetLock(locked: false);
        if (context.mounted) {
          TopIslandToast.show(
            context,
            message: '$count notes unlocked',
            icon: Icons.lock_open_rounded,
            color: AppColors.accentEmerald,
          );
        }
      }
    }
  }

  void _showBatchDeleteDialog(BuildContext context, WidgetRef ref, int count) {
    final isTrash = ref.read(notesLibraryProvider).selectedCategory == 'Trash';
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF2E2E2E)),
        ),
        title: Text(
          isTrash
              ? 'Permanently delete $count ${count == 1 ? 'Note' : 'Notes'}?'
              : 'Move $count ${count == 1 ? 'Note' : 'Notes'} to Trash?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          isTrash
              ? 'Permanently remove $count selected ${count == 1 ? 'note' : 'notes'} from device? This action cannot be undone.'
              : '$count selected ${count == 1 ? 'note' : 'notes'} will be moved to Trash and can be restored within 30 days.',
          style: const TextStyle(color: AppColors.amoledTextSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(notesLibraryProvider.notifier).batchDeleteSelected();
              TopIslandToast.show(
                context,
                message: isTrash
                    ? '$count ${count == 1 ? 'note' : 'notes'} permanently deleted'
                    : '$count ${count == 1 ? 'note' : 'notes'} moved to Trash',
                icon: isTrash ? Icons.delete_forever_rounded : Icons.delete_outline_rounded,
                color: AppColors.accentRose,
              );
            },
            child: Text(isTrash ? 'Delete Forever' : 'Move to Trash', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static String _cleanPreviewText(NoteDocument note) {
    if (note.metadata.isLocked) return '•••• •••••••• ••••••';
    if (note.blocks.isEmpty) return '';
    final raw = note.blocks.map((b) => b.rawText).join(' ');
    return raw
        .replaceAll('*', '')
        .replaceAll('~', '')
        .replaceAll('`', '')
        .replaceAll('#', '')
        .replaceAll(RegExp(r'\[\s*[xX ]\s*\]'), '☐')
        .replaceAll(RegExp(r'(^|\s)>\s*'), ' ')
        .replaceAll(RegExp(r'(^|\s)-\s*'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static Widget _buildCategoryChip({
    required String label,
    IconData? icon,
    required int count,
    required bool isSelected,
    required AppThemePalette activeTheme,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? activeTheme.accent.withValues(alpha: 0.18) : activeTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? activeTheme.accent : activeTheme.border,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: isSelected ? activeTheme.accent : activeTheme.textSecondary,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? activeTheme.accent : activeTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? activeTheme.accent.withValues(alpha: 0.25) : const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? activeTheme.accent : const Color(0xFF888888),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridCard(BuildContext context, WidgetRef ref, NoteDocument note, NotesLibraryState libraryState) {
    final isLocked = note.metadata.isLocked;
    final isDeleted = note.metadata.isDeleted;
    final showWordCount = ref.watch(settingsProvider.select((s) => s.showWordCount));
    final activeTheme = ref.watch(appThemeProvider);
    final previewText = _cleanPreviewText(note);
    final title = note.metadata.title.isNotEmpty ? note.metadata.title : 'Untitled Note';
    final isSelected = libraryState.selectedNoteIds.contains(note.metadata.id);

    return HoldToSelectBorderCard(
      isSelected: isSelected,
      isSelectionMode: libraryState.isSelectionMode,
      onTap: () {
        if (libraryState.isSelectionMode) {
          ref.read(notesLibraryProvider.notifier).toggleNoteSelection(note.metadata.id);
        } else {
          _handleNoteTap(context, ref, note);
        }
      },
      onHoldCompleted: () {
        ref.read(notesLibraryProvider.notifier).toggleNoteSelection(note.metadata.id);
      },
      child: Container(
        decoration: BoxDecoration(
          color: activeTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? activeTheme.accent
                : (isDeleted
                    ? AppColors.accentRose.withValues(alpha: 0.4)
                    : (isLocked ? activeTheme.accent.withValues(alpha: 0.5) : activeTheme.border)),
            width: isSelected ? 2.0 : 1.2,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isLocked) ...[
                  Icon(Icons.lock, size: 16, color: activeTheme.accent),
                  const SizedBox(width: 6),
                ],
                if (isDeleted) ...[
                  const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.accentRose),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: activeTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Expanded(
              child: Text(
                previewText.isNotEmpty ? previewText : 'Empty note',
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isLocked ? Colors.white30 : activeTheme.textSecondary,
                  letterSpacing: isLocked ? 2.0 : null,
                ),
              ),
            ),
            const SizedBox(height: 6),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isDeleted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accentRose.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${note.metadata.daysUntilPermanentDeletion}d left',
                      style: const TextStyle(fontSize: 10.5, color: AppColors.accentRose, fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  Text(
                    _formatDate(note.metadata.modifiedAt),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF666666), fontWeight: FontWeight.w500),
                  ),
                Row(
                  children: [
                    if (!isDeleted && showWordCount && note.metadata.wordCount > 0) ...[
                      Text(
                        '${note.metadata.wordCount}w',
                        style: TextStyle(fontSize: 11, color: activeTheme.accent, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                    ],
                    GestureDetector(
                      onTap: () => _showNoteActions(context, ref, note),
                      child: const Icon(Icons.more_horiz, size: 18, color: Colors.white38),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListCard(BuildContext context, WidgetRef ref, NoteDocument note, NotesLibraryState libraryState) {
    final isLocked = note.metadata.isLocked;
    final isDeleted = note.metadata.isDeleted;
    final showWordCount = ref.watch(settingsProvider.select((s) => s.showWordCount));
    final activeTheme = ref.watch(appThemeProvider);
    final previewText = _cleanPreviewText(note);
    final title = note.metadata.title.isNotEmpty ? note.metadata.title : 'Untitled Note';
    final isSelected = libraryState.selectedNoteIds.contains(note.metadata.id);

    return HoldToSelectBorderCard(
      isSelected: isSelected,
      isSelectionMode: libraryState.isSelectionMode,
      onTap: () {
        if (libraryState.isSelectionMode) {
          ref.read(notesLibraryProvider.notifier).toggleNoteSelection(note.metadata.id);
        } else {
          _handleNoteTap(context, ref, note);
        }
      },
      onHoldCompleted: () {
        ref.read(notesLibraryProvider.notifier).toggleNoteSelection(note.metadata.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: activeTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? activeTheme.accent
                : (isDeleted
                    ? AppColors.accentRose.withValues(alpha: 0.4)
                    : (isLocked ? activeTheme.accent.withValues(alpha: 0.5) : activeTheme.border)),
            width: isSelected ? 2.0 : 1.2,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (isLocked) ...[
                        Icon(Icons.lock, size: 16, color: activeTheme.accent),
                        const SizedBox(width: 6),
                      ],
                      if (isDeleted) ...[
                        const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.accentRose),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: activeTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatDate(note.metadata.modifiedAt),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF666666), fontWeight: FontWeight.w500),
                ),
              ],
            ),
            if (previewText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                previewText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isLocked ? Colors.white30 : activeTheme.textSecondary,
                  letterSpacing: isLocked ? 2.0 : null,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isDeleted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accentRose.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${note.metadata.daysUntilPermanentDeletion} days left in Trash',
                      style: const TextStyle(fontSize: 11, color: AppColors.accentRose, fontWeight: FontWeight.bold),
                    ),
                  )
                else if (showWordCount && note.metadata.wordCount > 0)
                  Text(
                    '${note.metadata.wordCount} words',
                    style: TextStyle(fontSize: 11, color: activeTheme.accent, fontWeight: FontWeight.bold),
                  )
                else
                  const SizedBox.shrink(),
                GestureDetector(
                  onTap: () => _showNoteActions(context, ref, note),
                  child: const Icon(Icons.more_horiz, size: 20, color: Colors.white38),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(notesLibraryProvider);
    final activeTheme = ref.watch(appThemeProvider);
    final isTrash = libraryState.selectedCategory == 'Trash';
    final isFav = libraryState.selectedCategory == 'Favorites';

    final icon = isTrash
        ? Icons.delete_outline_rounded
        : (isFav ? Icons.star_border_rounded : Icons.edit_note_rounded);
    final iconColor = isTrash ? AppColors.accentRose : (isFav ? const Color(0xFFFBBF24) : activeTheme.accent);
    final title = isTrash
        ? 'Trash is empty'
        : (isFav ? 'No favorites yet' : 'No notes yet');
    final subtitle = isTrash
        ? 'Deleted notes stay here for 30 days before permanent auto-purge'
        : (isFav
            ? 'Star any note from its menu to see it here'
            : 'Tap Write below to capture ideas or write a journal');

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: activeTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: activeTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      return 'Today $hour:$min $ampm';
    }
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }
}
