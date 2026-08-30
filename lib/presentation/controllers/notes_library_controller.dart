import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../domain/models/note_document.dart';
import '../../infrastructure/sync/models/sync_models.dart';

class NotesLibraryState {
  final List<NoteDocument> notes;
  final String searchQuery;
  final String selectedCategory;
  final bool isGridView;
  final bool isLoading;

  const NotesLibraryState({
    this.notes = const [],
    this.searchQuery = '',
    this.selectedCategory = 'All',
    this.isGridView = true,
    this.isLoading = true,
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
    bool? isLoading,
  }) {
    return NotesLibraryState(
      notes: notes ?? this.notes,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      isGridView: isGridView ?? this.isGridView,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class NotesLibraryNotifier extends StateNotifier<NotesLibraryState> {
  Directory? _notesDir;
  final Map<String, int> _tombstones = {}; // noteId -> deletion timestamp epoch ms

  NotesLibraryNotifier() : super(const NotesLibraryState(notes: [], isLoading: true)) {
    _initStorage();
  }

  Future<void> _initStorage() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _notesDir = Directory(p.join(appDir.path, 'wznotes_data'));
      if (!_notesDir!.existsSync()) {
        _notesDir!.createSync(recursive: true);
      }
      _loadTombstones();
      await _loadNotesFromDisk();
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void _loadTombstones() {
    if (_notesDir == null) return;
    try {
      final file = File(p.join(_notesDir!.path, 'tombstones.json'));
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        final Map<String, dynamic> jsonMap = json.decode(content) as Map<String, dynamic>;
        for (final entry in jsonMap.entries) {
          if (entry.value is int) {
            _tombstones[entry.key] = entry.value as int;
          }
        }
      }
    } catch (_) {}
  }

  void _persistTombstones() {
    if (_notesDir == null) return;
    try {
      final file = File(p.join(_notesDir!.path, 'tombstones.json'));
      file.writeAsStringSync(json.encode(_tombstones));
    } catch (_) {}
  }

  Future<void> _loadNotesFromDisk() async {
    if (_notesDir == null || !_notesDir!.existsSync()) {
      state = state.copyWith(isLoading: false);
      return;
    }

    final List<NoteDocument> loaded = [];
    final files = _notesDir!.listSync();

    for (final f in files) {
      if (f is File && f.path.endsWith('.json') && !p.basename(f.path).startsWith('tombstones')) {
        try {
          final content = await f.readAsString();
          final Map<String, dynamic> jsonMap = json.decode(content) as Map<String, dynamic>;
          final doc = NoteDocument.fromJson(jsonMap);
          loaded.add(doc);
        } catch (_) {}
      }
    }

    // Sort by modified date descending
    loaded.sort((a, b) => b.metadata.modifiedAt.compareTo(a.metadata.modifiedAt));

    state = state.copyWith(notes: loaded, isLoading: false);
  }

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
    final hasContent = updatedDoc.metadata.title.trim().isNotEmpty ||
        updatedDoc.blocks.any((b) => b.rawText.trim().isNotEmpty) ||
        updatedDoc.strokes.isNotEmpty;

    final existingIndex = state.notes.indexWhere((n) => n.metadata.id == updatedDoc.metadata.id);

    if (!hasContent) {
      if (existingIndex >= 0) {
        deleteNote(updatedDoc.metadata.id);
      }
      return;
    }

    final docToSave = updatedDoc.recalculateStats();

    // Clear tombstone if re-created
    _tombstones.remove(docToSave.metadata.id);
    _persistTombstones();

    if (existingIndex >= 0) {
      final updatedList = List<NoteDocument>.from(state.notes);
      updatedList[existingIndex] = docToSave;
      state = state.copyWith(notes: updatedList);
    } else {
      state = state.copyWith(notes: [docToSave, ...state.notes]);
    }

    _persistNoteToDisk(docToSave);
  }

  void _persistNoteToDisk(NoteDocument doc) {
    if (_notesDir == null) return;
    try {
      final file = File(p.join(_notesDir!.path, '${doc.metadata.id}.json'));
      final jsonString = json.encode(doc.toJson());
      file.writeAsStringSync(jsonString);
    } catch (_) {}
  }

  void deleteNote(String noteId) {
    state = state.copyWith(
      notes: state.notes.where((n) => n.metadata.id != noteId).toList(),
    );

    // Record tombstone
    _tombstones[noteId] = DateTime.now().millisecondsSinceEpoch;
    _persistTombstones();

    if (_notesDir != null) {
      try {
        final file = File(p.join(_notesDir!.path, '$noteId.json'));
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (_) {}
    }
  }

  void batchDeleteNotes(List<String> noteIds) {
    for (final id in noteIds) {
      deleteNote(id);
    }
  }

  void toggleFavorite(String noteId) {
    final noteIndex = state.notes.indexWhere((n) => n.metadata.id == noteId);
    if (noteIndex < 0) return;

    final note = state.notes[noteIndex];
    final isFav = note.metadata.folderId == 'favorites';
    final updated = note.copyWith(
      metadata: note.metadata.copyWith(
        folderId: isFav ? 'root' : 'favorites',
        modifiedAt: DateTime.now(),
      ),
    );

    final updatedList = List<NoteDocument>.from(state.notes);
    updatedList[noteIndex] = updated;
    state = state.copyWith(notes: updatedList);

    _persistNoteToDisk(updated);
  }

  // --- SYNC ENGINE INTEGRATION ---

  SyncManifest getSyncManifest({String deviceId = '', String deviceName = 'Device'}) {
    final List<SyncNoteHeader> headers = [];

    // Active notes
    for (final note in state.notes) {
      headers.add(SyncNoteHeader(
        id: note.metadata.id,
        modifiedAt: note.metadata.modifiedAt.millisecondsSinceEpoch,
        isDeleted: false,
        title: note.metadata.title,
      ));
    }

    // Tombstones
    for (final entry in _tombstones.entries) {
      headers.add(SyncNoteHeader(
        id: entry.key,
        modifiedAt: entry.value,
        isDeleted: true,
      ));
    }

    return SyncManifest(
      deviceId: deviceId,
      deviceName: deviceName,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      notes: headers,
    );
  }

  List<NoteDocument> getNotesByIds(List<String> ids) {
    final idSet = ids.toSet();
    return state.notes.where((n) => idSet.contains(n.metadata.id)).toList();
  }

  void importSyncedNotes(List<NoteDocument> incoming) {
    if (incoming.isEmpty) return;

    final Map<String, NoteDocument> currentNotesMap = {
      for (final n in state.notes) n.metadata.id: n,
    };

    for (final doc in incoming) {
      final local = currentNotesMap[doc.metadata.id];
      if (local == null) {
        // Brand new note from peer
        currentNotesMap[doc.metadata.id] = doc;
        _tombstones.remove(doc.metadata.id);
        _persistNoteToDisk(doc);
      } else {
        // Existing note: only update if incoming is newer or equal
        if (doc.metadata.modifiedAt.isAfter(local.metadata.modifiedAt) ||
            doc.metadata.modifiedAt.isAtSameMomentAs(local.metadata.modifiedAt)) {
          currentNotesMap[doc.metadata.id] = doc;
          _persistNoteToDisk(doc);
        }
      }
    }

    _persistTombstones();

    final updatedList = currentNotesMap.values.toList();
    updatedList.sort((a, b) => b.metadata.modifiedAt.compareTo(a.metadata.modifiedAt));

    state = state.copyWith(notes: updatedList);
  }
}

final notesLibraryProvider = StateNotifierProvider<NotesLibraryNotifier, NotesLibraryState>((ref) {
  return NotesLibraryNotifier();
});
