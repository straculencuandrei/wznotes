import 'package:flutter_test/flutter_test.dart';
import 'package:wznotes/domain/models/note_document.dart';
import 'package:wznotes/infrastructure/sync/models/sync_models.dart';
import 'package:wznotes/infrastructure/sync/sync_engine.dart';

void main() {
  group('SyncEngine Delta Computation Tests', () {
    test('Identifies new notes to send and fetch correctly', () {
      const localManifest = SyncManifest(
        deviceId: 'pc-1',
        deviceName: 'Windows PC',
        timestamp: 1000,
        notes: [
          SyncNoteHeader(id: 'note-1', modifiedAt: 500, title: 'Local Note 1'),
          SyncNoteHeader(id: 'note-shared', modifiedAt: 800, title: 'Shared Note'),
        ],
      );

      const peerManifest = SyncManifest(
        deviceId: 'phone-1',
        deviceName: 'Android Phone',
        timestamp: 1000,
        notes: [
          SyncNoteHeader(id: 'note-2', modifiedAt: 600, title: 'Phone Note 2'),
          SyncNoteHeader(id: 'note-shared', modifiedAt: 400, title: 'Shared Note'),
        ],
      );

      final delta = SyncEngine.calculateDelta(
        localManifest: localManifest,
        peerManifest: peerManifest,
      );

      // Local has note-1 which peer doesn't have -> notesToSend
      expect(delta.notesToSend, contains('note-1'));
      // Local has newer version of note-shared (800 vs 400) -> notesToSend
      expect(delta.notesToSend, contains('note-shared'));
      // Peer has note-2 which local doesn't have -> notesToFetch
      expect(delta.notesToFetch, contains('note-2'));
      // No deletions
      expect(delta.notesToDeleteLocally, isEmpty);
      expect(delta.tombstonesToSend, isEmpty);
    });

    test('Propagates deletions via tombstones', () {
      const localManifest = SyncManifest(
        deviceId: 'pc-1',
        deviceName: 'Windows PC',
        timestamp: 1000,
        notes: [
          SyncNoteHeader(id: 'note-deleted-on-peer', modifiedAt: 200, title: 'Old Note'),
        ],
      );

      const peerManifest = SyncManifest(
        deviceId: 'phone-1',
        deviceName: 'Android Phone',
        timestamp: 1000,
        notes: [
          SyncNoteHeader(
            id: 'note-deleted-on-peer',
            modifiedAt: 300,
            isDeleted: true,
          ),
        ],
      );

      final delta = SyncEngine.calculateDelta(
        localManifest: localManifest,
        peerManifest: peerManifest,
      );

      // Peer deleted after local modification -> mark for local deletion
      expect(delta.notesToDeleteLocally, contains('note-deleted-on-peer'));
      expect(delta.notesToSend, isEmpty);
    });

    test('Resolves conflicts using latest modifiedAt timestamp', () {
      final base1 = NoteDocument.initial(title: 'Older');
      final doc1 = base1.copyWith(metadata: base1.metadata.copyWith(modifiedAt: DateTime(2026, 1, 1)));

      final base2 = NoteDocument.initial(title: 'Newer');
      final doc2 = base2.copyWith(metadata: base2.metadata.copyWith(modifiedAt: DateTime(2026, 2, 1)));

      final winner = SyncEngine.resolveConflict(doc1, doc2);
      expect(winner?.metadata.title, equals('Newer'));
    });
  });
}
