import 'package:flutter_test/flutter_test.dart';
import 'package:wznotes/domain/models/note_document.dart';
import 'package:wznotes/presentation/controllers/notes_library_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Note Security & Lock PIN Tests', () {
    test('NoteMetadata.copyWith clears lockPin when isLocked is set to false', () {
      final meta = NoteMetadata(
        id: 'test-1',
        title: 'Secret Note',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        isLocked: true,
        lockPin: '8888',
      );

      expect(meta.isLocked, isTrue);
      expect(meta.lockPin, equals('8888'));

      // Unlocking clears lockPin
      final unlocked = meta.copyWith(isLocked: false);
      expect(unlocked.isLocked, isFalse);
      expect(unlocked.lockPin, isNull);
    });

    test('NoteMetadata.copyWith retains lockPin when note remains locked', () {
      final meta = NoteMetadata(
        id: 'test-2',
        title: 'Secret Note 2',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        isLocked: true,
        lockPin: '5678',
      );

      final updatedTitle = meta.copyWith(title: 'Updated Title');
      expect(updatedTitle.isLocked, isTrue);
      expect(updatedTitle.lockPin, equals('5678'));
    });

    test('updateLockPinForLockedNotes updates PIN only for locked notes', () {
      final notifier = NotesLibraryNotifier();

      final lockedNote = NoteDocument(
        metadata: NoteMetadata(
          id: 'locked-1',
          title: 'Locked Note',
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
          isLocked: true,
          lockPin: '1234',
        ),
      );

      final unlockedNote = NoteDocument(
        metadata: NoteMetadata(
          id: 'unlocked-1',
          title: 'Unlocked Note',
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
          isLocked: false,
        ),
      );

      notifier.saveNote(lockedNote);
      notifier.saveNote(unlockedNote);

      notifier.updateLockPinForLockedNotes('9999');

      final l1 = notifier.state.notes.firstWhere((n) => n.metadata.id == 'locked-1');
      final u1 = notifier.state.notes.firstWhere((n) => n.metadata.id == 'unlocked-1');

      expect(l1.metadata.lockPin, equals('9999'));
      expect(l1.metadata.isLocked, isTrue);
      expect(u1.metadata.lockPin, isNull);
      expect(u1.metadata.isLocked, isFalse);
    });
  });
}
