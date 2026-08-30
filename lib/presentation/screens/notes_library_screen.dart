import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../domain/models/note_document.dart';
import '../controllers/notes_library_controller.dart';
import '../controllers/document_controller.dart';
import 'note_editor_screen.dart';

/// Pure AMOLED Samsung Notes Inspired Home Library Screen
class NotesLibraryScreen extends ConsumerWidget {
  const NotesLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(notesLibraryProvider);
    final libraryNotifier = ref.read(notesLibraryProvider.notifier);
    final notes = libraryState.filteredNotes;

    return Scaffold(
      backgroundColor: AppColors.amoledBlack,
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, _) {
            return [
              // 1. Large Samsung One UI Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(left: 24, right: 20, top: 24, bottom: 12),
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
                      IconButton(
                        icon: Icon(
                          libraryState.isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                          color: AppColors.amoledTextPrimary,
                          size: 26,
                        ),
                        tooltip: libraryState.isGridView ? 'List View' : 'Grid View',
                        onPressed: () => libraryNotifier.toggleViewLayout(),
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
            ];
          },
          body: notes.isEmpty
              ? _buildEmptyState(context, ref)
              : libraryState.isGridView
                  ? _buildGridView(context, ref, notes)
                  : _buildListView(context, ref, notes),
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
          ref.read(documentProvider.notifier).setDocument(newDoc);
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const NoteEditorScreen()),
          );
        },
      ),
    );
  }

  Widget _buildGridView(BuildContext context, WidgetRef ref, List<NoteDocument> notes) {
    return GridView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.82,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        return _buildNoteCard(context, ref, notes[index]);
      },
    );
  }

  Widget _buildListView(BuildContext context, WidgetRef ref, List<NoteDocument> notes) {
    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 100),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: _buildNoteCard(context, ref, notes[index], isList: true),
        );
      },
    );
  }

  Widget _buildNoteCard(BuildContext context, WidgetRef ref, NoteDocument note, {bool isList = false}) {
    final previewText = note.blocks.isNotEmpty ? note.blocks.first.rawText : '';
    final title = note.metadata.title.isNotEmpty ? note.metadata.title : 'Untitled Note';

    return GestureDetector(
      onTap: () {
        ref.read(documentProvider.notifier).setDocument(note);
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const NoteEditorScreen()),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.amoledSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.amoledBorder, width: 1.2),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Note Title
            Text(
              title,
              maxLines: isList ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.amoledTextPrimary,
              ),
            ),
            const SizedBox(height: 8),

            // Content Snippet
            Expanded(
              child: Text(
                previewText.isNotEmpty ? previewText : 'Empty note',
                maxLines: isList ? 2 : 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.amoledTextSecondary,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Date & Word count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDate(note.metadata.modifiedAt),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF666666), fontWeight: FontWeight.w500),
                ),
                if (note.metadata.wordCount > 0)
                  Text(
                    '${note.metadata.wordCount}w',
                    style: const TextStyle(fontSize: 12, color: AppColors.samsungOrange, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
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
