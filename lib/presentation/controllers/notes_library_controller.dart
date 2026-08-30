import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/note_document.dart';

class NotesLibraryState {
  final List<NoteDocument> notes;
  final String searchQuery;
  final String selectedCategory;
  final bool isGridView;

  const NotesLibraryState({
    this.notes = const [],
    this.searchQuery = '',
    this.selectedCategory = 'All',
    this.isGridView = true,
  });

  List<NoteDocument> get filteredNotes {
    return notes.where((note) {
      final matchesSearch = searchQuery.isEmpty ||
          note.metadata.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          note.blocks.any((b) => b.rawText.toLowerCase().contains(searchQuery.toLowerCase()));

      final matchesCategory = selectedCategory == 'All' ||
          (selectedCategory == 'Favorites' && note.metadata.folderId == 'favorites') ||
          note.metadata.tags.contains(selectedCategory.toLowerCase());

      return matchesSearch && matchesCategory;
    }).toList();
  }

  NotesLibraryState copyWith({
    List<NoteDocument>? notes,
    String? searchQuery,
    String? selectedCategory,
    bool? isGridView,
  }) {
    return NotesLibraryState(
      notes: notes ?? this.notes,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      isGridView: isGridView ?? this.isGridView,
    );
  }
}

class NotesLibraryNotifier extends StateNotifier<NotesLibraryState> {
  NotesLibraryNotifier() : super(const NotesLibraryState(notes: []));

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSelectedCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  void toggleViewLayout() {
    state = state.copyWith(isGridView: !state.isGridView);
  }

  NoteDocument createNewNote({String title = ''}) {
    return NoteDocument.initial(title: title);
  }

  void saveNote(NoteDocument updatedDoc) {
    // If note is completely empty (no title, no text, no strokes), don't save a blank ghost note
    final hasContent = updatedDoc.metadata.title.trim().isNotEmpty ||
        updatedDoc.blocks.any((b) => b.rawText.trim().isNotEmpty) ||
        updatedDoc.strokes.isNotEmpty;

    final existingIndex = state.notes.indexWhere((n) => n.metadata.id == updatedDoc.metadata.id);

    if (!hasContent) {
      // If an existing note was cleared of all content, remove it
      if (existingIndex >= 0) {
        deleteNote(updatedDoc.metadata.id);
      }
      return;
    }

    if (existingIndex >= 0) {
      final updatedList = List<NoteDocument>.from(state.notes);
      updatedList[existingIndex] = updatedDoc.recalculateStats();
      state = state.copyWith(notes: updatedList);
    } else {
      state = state.copyWith(notes: [updatedDoc.recalculateStats(), ...state.notes]);
    }
  }

  void deleteNote(String noteId) {
    state = state.copyWith(
      notes: state.notes.where((n) => n.metadata.id != noteId).toList(),
    );
  }

  void toggleFavorite(String noteId) {
    state = state.copyWith(
      notes: state.notes.map((n) {
        if (n.metadata.id == noteId) {
          final isFav = n.metadata.folderId == 'favorites';
          return n.copyWith(
            metadata: n.metadata.copyWith(folderId: isFav ? 'root' : 'favorites'),
          );
        }
        return n;
      }).toList(),
    );
  }
}

final notesLibraryProvider = StateNotifierProvider<NotesLibraryNotifier, NotesLibraryState>((ref) {
  return NotesLibraryNotifier();
});
