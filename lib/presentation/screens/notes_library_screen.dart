import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../domain/models/note_document.dart';
import '../controllers/notes_library_controller.dart';
import '../controllers/document_controller.dart';
import '../controllers/settings_controller.dart';
import '../../infrastructure/security/biometric_service.dart';
import '../controllers/update_controller.dart';
import '../widgets/update_dialog.dart';
import '../widgets/hold_to_select_border_card.dart';
import '../widgets/top_island_toast.dart';
import 'note_editor_screen.dart';
import 'settings_screen.dart';
import 'sync_screen.dart';

/// Pure AMOLED Samsung Notes Inspired Home Library Screen
class NotesLibraryScreen extends ConsumerWidget {
  const NotesLibraryScreen({super.key});

  Future<void> _handleNoteTap(BuildContext context, WidgetRef ref, NoteDocument note) async {
    if (note.metadata.isLocked) {
      final settings = ref.read(settingsProvider);
      bool isUnlocked = false;

      isUnlocked = await BiometricSecurityService.authenticate(
        reason: 'Scan fingerprint to unlock "${note.metadata.title}"',
      );

      if (!isUnlocked && context.mounted) {
        final pinToMatch = note.metadata.lockPin ?? settings.appPin;
        isUnlocked = await BiometricSecurityService.promptPin(
          context,
          correctPin: pinToMatch,
          alternativePins: [
            if (note.metadata.lockPin != null) note.metadata.lockPin!,
            settings.appPin,
            '1234',
          ],
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
          final curvedAnim = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curvedAnim,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1.0).animate(curvedAnim),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.06),
                  end: Offset.zero,
                ).animate(curvedAnim),
                child: child,
              ),
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  void _showNoteActions(BuildContext context, WidgetRef ref, NoteDocument note) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
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
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 20,
                offset: const Offset(0, 8),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF222222),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${note.metadata.wordCount}w • ${_formatDate(note.metadata.modifiedAt)}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF999999), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFF262626), height: 1),
                  const SizedBox(height: 8),

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
                    title: isLocked ? 'Unlock note' : 'Lock note with biometric / PIN',
                    subtitle: isLocked ? 'Remove password protection' : 'Requires fingerprint to open',
                    onTap: () async {
                      Navigator.of(context).pop();
                      if (!isLocked) {
                        final currentAppPin = ref.read(settingsProvider).appPin;
                        String? chosenPin = currentAppPin;

                        // If appPin is still default 1234, offer to set custom PIN
                        if (currentAppPin == '1234') {
                          final setPin = await BiometricSecurityService.promptSetPin(
                            context,
                            title: 'Lock Note with PIN',
                          );
                          if (setPin != null) {
                            chosenPin = setPin;
                            ref.read(settingsProvider.notifier).setPin(setPin);
                          }
                        }

                        final updated = note.copyWith(
                          metadata: note.metadata.copyWith(
                            isLocked: true,
                            lockPin: chosenPin,
                          ),
                        );
                        ref.read(notesLibraryProvider.notifier).saveNote(updated);
                        if (context.mounted) {
                          TopIslandToast.show(
                            context,
                            message: 'Note locked (PIN: ${chosenPin ?? "1234"})',
                            icon: Icons.lock_outline_rounded,
                            color: AppColors.accentEmerald,
                          );
                        }
                      } else {
                        bool isAuthed = await BiometricSecurityService.authenticate(reason: 'Verify fingerprint to unlock');
                        if (!isAuthed && context.mounted) {
                          final appPin = ref.read(settingsProvider).appPin;
                          isAuthed = await BiometricSecurityService.promptPin(
                            context,
                            correctPin: note.metadata.lockPin ?? appPin,
                            alternativePins: [
                              if (note.metadata.lockPin != null) note.metadata.lockPin!,
                              appPin,
                              '1234',
                            ],
                            title: 'Unlock Note',
                          );
                        }
                        if (isAuthed) {
                          final updated = note.copyWith(
                            metadata: note.metadata.copyWith(isLocked: false),
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

                  // 4. Delete
                  _buildCompactActionRow(
                    icon: Icons.delete_outline_rounded,
                    iconColor: AppColors.accentRose,
                    iconBg: AppColors.accentRose.withValues(alpha: 0.15),
                    title: 'Delete note',
                    titleColor: AppColors.accentRose,
                    onTap: () {
                      ref.read(notesLibraryProvider.notifier).deleteNote(note.metadata.id);
                      Navigator.of(context).pop();
                      TopIslandToast.show(
                        context,
                        message: 'Note deleted',
                        icon: Icons.delete_outline_rounded,
                        color: AppColors.accentRose,
                      );
                    },
                  ),
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
          SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
            if (!isSelectionMode) {
              final newDoc = ref.read(notesLibraryProvider.notifier).createNewNote();
              _openNote(context, ref, newDoc);
            }
          },
          SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true): () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SyncScreen()),
            );
          },
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: AppColors.amoledBlack,
body: Stack(
              children: [
                SafeArea(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // 1. Large Samsung One UI Header (or Selection Mode Header)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 24, right: 16, top: 24, bottom: 12),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 240),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.0, -0.08),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: isSelectionMode
                                ? Row(
                                    key: const ValueKey('selection_header'),
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
                                              fontSize: 24,
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
                                  )
                                : Row(
                                    key: const ValueKey('normal_header'),
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'All notes',
                                            style: TextStyle(
                                              fontSize: 34,
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.amoledTextPrimary,
                                              letterSpacing: -0.8,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${libraryState.notes.length} ${libraryState.notes.length == 1 ? 'note' : 'notes'}',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              color: AppColors.amoledTextSecondary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.sync_alt_rounded, color: AppColors.samsungOrange, size: 26),
                                            tooltip: 'Wi-Fi Device Sync (Ctrl+Shift+S)',
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute<void>(builder: (_) => const SyncScreen()),
                                              );
                                            },
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              libraryState.isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                                              color: AppColors.amoledTextPrimary,
                                              size: 26,
                                            ),
                                            tooltip: libraryState.isGridView ? 'List View' : 'Grid View',
                                            onPressed: () => libraryNotifier.toggleViewLayout(),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.settings_outlined, color: AppColors.amoledTextPrimary, size: 26),
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

                      // 1.5. In-App Update Alert Banner (Smooth collapse on selection mode)
                      SliverToBoxAdapter(
                        child: Consumer(
                          builder: (context, ref, _) {
                            final updateState = ref.watch(updateProvider);
                            final shouldShow = updateState.hasUpdate && !isSelectionMode;

                            return AnimatedSize(
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.topCenter,
                              child: !shouldShow
                                  ? const SizedBox(width: double.infinity, height: 0)
                                  : Padding(
                                      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
                                      child: AnimatedOpacity(
                                        opacity: isSelectionMode ? 0.0 : 1.0,
                                        duration: const Duration(milliseconds: 200),
                                        curve: Curves.easeOut,
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
                                                      'wznotes v${updateState.updateInfo?.version ?? ""} Available',
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
                                                  if (updateState.updateInfo != null) {
                                                    UpdateDialog.show(context, updateInfo: updateState.updateInfo!);
                                                  }
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
                            );
                          },
                        ),
                      ),

                      // 2. Big AMOLED Search Bar (Smooth glide and collapse on selection mode)
                      SliverToBoxAdapter(
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: isSelectionMode
                              ? const SizedBox(width: double.infinity, height: 0)
                              : Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  child: AnimatedOpacity(
                                    opacity: isSelectionMode ? 0.0 : 1.0,
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOut,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.amoledSurface,
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(color: AppColors.amoledBorder, width: 1.2),
                                      ),
                                      child: TextField(
                                        style: const TextStyle(fontSize: 16, color: AppColors.amoledTextPrimary),
                                        decoration: InputDecoration(
                                          hintText: 'Search notes...',
                                          hintStyle: const TextStyle(color: Color(0xFF555555), fontSize: 15),
                                          prefixIcon: const Icon(Icons.search, color: AppColors.samsungOrange, size: 24),
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
            // Samsung Notes Style Floating Action Button (Smooth scale and fade)
            floatingActionButton: AnimatedScale(
              scale: isSelectionMode ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: AnimatedOpacity(
                opacity: isSelectionMode ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 180),
                child: IgnorePointer(
                  ignoring: isSelectionMode,
                  child: FloatingActionButton.extended(
                    backgroundColor: AppColors.samsungOrange,
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

    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 18),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF181818),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppColors.samsungOrange.withValues(alpha: 0.6), width: 1.3),
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
                icon: const Icon(Icons.lock_outline_rounded, color: AppColors.samsungOrange, size: 23),
                tooltip: 'Lock / Unlock Notes',
                onPressed: selectedCount == 0
                    ? null
                    : () => _handleBatchLock(context, ref, state),
              ),

              // Delete
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.accentRose, size: 23),
                tooltip: 'Delete Selected',
                onPressed: selectedCount == 0
                    ? null
                    : () => _showBatchDeleteDialog(context, ref, selectedCount),
              ),

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
      // Lock all selected notes
      final currentAppPin = ref.read(settingsProvider).appPin;
      String? chosenPin = currentAppPin;

      if (currentAppPin == '1234') {
        final setPin = await BiometricSecurityService.promptSetPin(
          context,
          title: 'Lock $count Notes with PIN',
        );
        if (setPin != null) {
          chosenPin = setPin;
          ref.read(settingsProvider.notifier).setPin(setPin);
        }
      }

      ref.read(notesLibraryProvider.notifier).batchSetLock(locked: true, lockPin: chosenPin);
      if (context.mounted) {
        TopIslandToast.show(
          context,
          message: '$count notes locked (PIN: ${chosenPin ?? "1234"})',
          icon: Icons.lock_outline_rounded,
          color: AppColors.accentEmerald,
        );
      }
    } else {
      // Unlock all selected notes: verify auth first
      bool isAuthed = await BiometricSecurityService.authenticate(reason: 'Verify fingerprint to unlock notes');
      if (!isAuthed && context.mounted) {
        final appPin = ref.read(settingsProvider).appPin;
        isAuthed = await BiometricSecurityService.promptPin(
          context,
          correctPin: appPin,
          alternativePins: ['1234'],
          title: 'Unlock $count Notes',
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
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF2E2E2E)),
        ),
        title: Text(
          'Delete $count ${count == 1 ? 'Note' : 'Notes'}?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to permanently delete $count selected ${count == 1 ? 'note' : 'notes'}? This action cannot be undone.',
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
                message: '$count ${count == 1 ? 'note' : 'notes'} deleted',
                icon: Icons.delete_outline_rounded,
                color: AppColors.accentRose,
              );
            },
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildGridCard(BuildContext context, WidgetRef ref, NoteDocument note, NotesLibraryState libraryState) {
    final isLocked = note.metadata.isLocked;
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
        if (!libraryState.isSelectionMode) {
          ref.read(notesLibraryProvider.notifier).toggleNoteSelection(note.metadata.id);
        } else {
          ref.read(notesLibraryProvider.notifier).toggleNoteSelection(note.metadata.id);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.amoledSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isLocked ? AppColors.samsungOrange.withValues(alpha: 0.5) : AppColors.amoledBorder,
            width: 1.2,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isLocked) ...[
                  const Icon(Icons.lock, size: 16, color: AppColors.samsungOrange),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.amoledTextPrimary,
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
                  color: isLocked ? Colors.white30 : AppColors.amoledTextSecondary,
                  letterSpacing: isLocked ? 2.0 : null,
                ),
              ),
            ),
            const SizedBox(height: 6),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDate(note.metadata.modifiedAt),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF666666), fontWeight: FontWeight.w500),
                ),
                if (note.metadata.wordCount > 0)
                  Text(
                    '${note.metadata.wordCount}w',
                    style: const TextStyle(fontSize: 11, color: AppColors.samsungOrange, fontWeight: FontWeight.bold),
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
        if (!libraryState.isSelectionMode) {
          ref.read(notesLibraryProvider.notifier).toggleNoteSelection(note.metadata.id);
        } else {
          ref.read(notesLibraryProvider.notifier).toggleNoteSelection(note.metadata.id);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.amoledSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isLocked ? AppColors.samsungOrange.withValues(alpha: 0.5) : AppColors.amoledBorder,
            width: 1.2,
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
                        const Icon(Icons.lock, size: 16, color: AppColors.samsungOrange),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.amoledTextPrimary,
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
                  color: isLocked ? Colors.white30 : AppColors.amoledTextSecondary,
                  letterSpacing: isLocked ? 2.0 : null,
                ),
              ),
            ],
            if (note.metadata.wordCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${note.metadata.wordCount} words',
                style: const TextStyle(fontSize: 11, color: AppColors.samsungOrange, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.samsungOrange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.edit_note,
              size: 48,
              color: AppColors.samsungOrange,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No notes yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.amoledTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap Write below to capture ideas or write a journal',
            style: TextStyle(fontSize: 14, color: AppColors.amoledTextSecondary),
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
