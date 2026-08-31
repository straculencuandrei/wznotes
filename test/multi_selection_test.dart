import 'package:flutter_test/flutter_test.dart';
import 'package:wznotes/domain/models/note_document.dart';
import 'package:wznotes/presentation/controllers/notes_library_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotesLibrary Multi-Selection & Batch Operations', () {
    late NotesLibraryNotifier notifier;

    setUp(() {
      notifier = NotesLibraryNotifier();
    });

    test('Initial selection state is empty and isSelectionMode is false', () {
      expect(notifier.state.selectedNoteIds, isEmpty);
      expect(notifier.state.isSelectionMode, isFalse);
    });

    test('toggleNoteSelection selects and deselects note IDs', () {
      notifier.toggleNoteSelection('note-1');
      expect(notifier.state.selectedNoteIds, contains('note-1'));
      expect(notifier.state.isSelectionMode, isTrue);

      notifier.toggleNoteSelection('note-2');
      expect(notifier.state.selectedNoteIds.length, equals(2));
      expect(notifier.state.selectedNoteIds, containsAll(['note-1', 'note-2']));

      notifier.toggleNoteSelection('note-1');
      expect(notifier.state.selectedNoteIds, equals({'note-2'}));

      notifier.clearSelection();
      expect(notifier.state.selectedNoteIds, isEmpty);
      expect(notifier.state.isSelectionMode, isFalse);
    });

    test('batchToggleFavorite updates favorite status on selected notes', () {
      final doc1 = NoteDocument(
        metadata: NoteMetadata(id: 'note-1', title: 'Note 1', createdAt: DateTime.now(), modifiedAt: DateTime.now(), folderId: 'root'),
        blocks: [],
        strokes: [],
      );
      final doc2 = NoteDocument(
        metadata: NoteMetadata(id: 'note-2', title: 'Note 2', createdAt: DateTime.now(), modifiedAt: DateTime.now(), folderId: 'root'),
        blocks: [],
        strokes: [],
      );

      notifier.saveNote(doc1);
      notifier.saveNote(doc2);

      notifier.toggleNoteSelection('note-1');
      notifier.toggleNoteSelection('note-2');
      notifier.batchToggleFavorite(setAsFavorite: true);

      final n1 = notifier.state.notes.firstWhere((n) => n.metadata.id == 'note-1');
      final n2 = notifier.state.notes.firstWhere((n) => n.metadata.id == 'note-2');

      expect(n1.metadata.folderId, equals('favorites'));
      expect(n2.metadata.folderId, equals('favorites'));
      expect(notifier.state.isSelectionMode, isFalse);
    });

    test('batchSetLock locks and unlocks selected notes', () {
      final doc = NoteDocument(
        metadata: NoteMetadata(id: 'note-lock', title: 'Lock Me', createdAt: DateTime.now(), modifiedAt: DateTime.now()),
        blocks: [],
        strokes: [],
      );

      notifier.saveNote(doc);
      notifier.toggleNoteSelection('note-lock');
      notifier.batchSetLock(locked: true, lockPin: '4321');

      var updated = notifier.state.notes.firstWhere((n) => n.metadata.id == 'note-lock');
      expect(updated.metadata.isLocked, isTrue);
      expect(updated.metadata.lockPin, equals('4321'));

      notifier.toggleNoteSelection('note-lock');
      notifier.batchSetLock(locked: false);

      updated = notifier.state.notes.firstWhere((n) => n.metadata.id == 'note-lock');
      expect(updated.metadata.isLocked, isFalse);
      expect(updated.metadata.lockPin, isNull);
    });
  });
}
