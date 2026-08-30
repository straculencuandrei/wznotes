import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../domain/models/note_document.dart';
import '../controllers/notes_library_controller.dart';
import '../controllers/document_controller.dart';
import '../controllers/settings_controller.dart';
import '../../infrastructure/security/biometric_service.dart';
import 'note_editor_screen.dart';
import 'settings_screen.dart';

/// Pure AMOLED Samsung Notes Inspired Home Library Screen
class NotesLibraryScreen extends ConsumerWidget {
  const NotesLibraryScreen({super.key});

  Future<void> _handleNoteTap(BuildContext context, WidgetRef ref, NoteDocument note) async {
    // If note is locked, require Fingerprint / Biometric / PIN unlock
    if (note.metadata.isLocked) {
      final settings = ref.read(settingsProvider);
      bool isUnlocked = false;

      // Try Fingerprint first
      isUnlocked = await BiometricSecurityService.authenticate(
        reason: 'Scan fingerprint to unlock "${note.metadata.title}"',
      );

      // Fallback to PIN if fingerprint not verified
      if (!isUnlocked && context.mounted) {
        final pinToMatch = note.metadata.lockPin ?? settings.appPin;
        isUnlocked = await BiometricSecurityService.promptPin(
          context,
          correctPin: pinToMatch,
          title: 'Unlock Note',
        );
      }

      if (!isUnlocked) {
        return; // User cancelled or failed authentication
      }
    }

    if (!context.mounted) return;
    _openNote(context, ref, note);
  }

  void _openNote(BuildContext context, WidgetRef ref, NoteDocument note) {
    ref.read(documentProvider.notifier).setDocument(note);
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => const NoteEditorScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  void _showNoteActions(BuildContext context, WidgetRef ref, NoteDocument note) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.amoledSurfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final isFav = note.metadata.folderId == 'favorites';
        final isLocked = note.metadata.isLocked;
        final title = note.metadata.title.isNotEmpty ? note.metadata.title : 'Untitled Note';

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.amoledTextPrimary,
                    ),
                  ),
                ),
                const Divider(color: AppColors.amoledBorder),

                // 1. Lock / Unlock Note with Fingerprint & PIN
                ListTile(
                  leading: Icon(
                    isLocked ? Icons.lock_open : Icons.lock_outline,
                    color: AppColors.samsungOrange,
                  ),
                  title: Text(
                    isLocked ? 'Unlock note (Remove protection)' : 'Lock note (Fingerprint / PIN)',
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    if (!isLocked) {
                      // Lock note
                      final updated = note.copyWith(
                        metadata: note.metadata.copyWith(isLocked: true),
                      );
                      ref.read(notesLibraryProvider.notifier).saveNote(updated);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Note locked with fingerprint & PIN')),
                      );
                    } else {
                      // Verify before unlocking
                      final isAuthed = await BiometricSecurityService.authenticate(reason: 'Verify fingerprint to unlock');
                      if (isAuthed) {
                        final updated = note.copyWith(
                          metadata: note.metadata.copyWith(isLocked: false),
                        );
                        ref.read(notesLibraryProvider.notifier).saveNote(updated);
                      }
                    }
                  },
                ),

                // 2. Favorite
                ListTile(
                  leading: Icon(
                    isFav ? Icons.star : Icons.star_border,
                    color: isFav ? const Color(0xFFFBBF24) : Colors.white70,
                  ),
                  title: Text(
                    isFav ? 'Remove from favorites' : 'Add to favorites',
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  onTap: () {
                    ref.read(notesLibraryProvider.notifier).toggleFavorite(note.metadata.id);
                    Navigator.of(context).pop();
                  },
                ),

                // 3. Delete
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppColors.accentRose),
                  title: const Text(
                    'Delete note',
                    style: TextStyle(color: AppColors.accentRose, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    ref.read(notesLibraryProvider.notifier).deleteNote(note.metadata.id);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Note deleted'),
                        duration: Duration(seconds: 2),
                        backgroundColor: AppColors.amoledSurface,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(notesLibraryProvider);
    final libraryNotifier = ref.read(notesLibraryProvider.notifier);
    final notes = libraryState.filteredNotes;

    return Scaffold(
      backgroundColor: AppColors.amoledBlack,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 1. Large Samsung One UI Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 24, right: 16, top: 24, bottom: 12),
                child: Row(
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
                        // Grid / List Layout Switcher
                        IconButton(
                          icon: Icon(
                            libraryState.isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                            color: AppColors.amoledTextPrimary,
                            size: 26,
                          ),
                          tooltip: libraryState.isGridView ? 'List View' : 'Grid View',
                          onPressed: () => libraryNotifier.toggleViewLayout(),
                        ),
                        // Settings Gear Icon
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

            // 2. Big AMOLED Search Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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

            // 3. Notes Content with Smooth Animated View Transitions
            if (notes.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(context, ref),
              )
            else if (libraryState.isGridView)
              SliverPadding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 100),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildGridCard(context, ref, notes[index]),
                    childCount: notes.length,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildListCard(context, ref, notes[index]),
                    childCount: notes.length,
                  ),
                ),
              ),
          ],
        ),
      ),
      // Samsung Notes Style Floating Action Button
      floatingActionButton: FloatingActionButton.extended(
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
    );
  }

  Widget _buildGridCard(BuildContext context, WidgetRef ref, NoteDocument note) {
    final isLocked = note.metadata.isLocked;
    final previewText = isLocked
        ? '•••• •••••••• ••••••'
        : (note.blocks.isNotEmpty ? note.blocks.map((b) => b.rawText).join(' ') : '');
    final title = note.metadata.title.isNotEmpty ? note.metadata.title : 'Untitled Note';

    return InkWell(
      onTap: () => _handleNoteTap(context, ref, note),
      onLongPress: () => _showNoteActions(context, ref, note),
      borderRadius: BorderRadius.circular(20),
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
            // Title & Lock Status
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

            // Content Snippet
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

            // Date & Word count
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

  Widget _buildListCard(BuildContext context, WidgetRef ref, NoteDocument note) {
    final isLocked = note.metadata.isLocked;
    final previewText = isLocked
        ? '•••• •••••••• ••••••'
        : (note.blocks.isNotEmpty ? note.blocks.map((b) => b.rawText).join(' ') : '');
    final title = note.metadata.title.isNotEmpty ? note.metadata.title : 'Untitled Note';

    return InkWell(
      onTap: () => _handleNoteTap(context, ref, note),
      onLongPress: () => _showNoteActions(context, ref, note),
      borderRadius: BorderRadius.circular(20),
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
