import '../../domain/models/note_document.dart';
import '../sync/models/sync_models.dart';

class SyncDelta {
  final List<String> notesToSend;
  final List<String> notesToFetch;
  final List<String> notesToDeleteLocally;
  final List<String> tombstonesToSend;

  const SyncDelta({
    required this.notesToSend,
    required this.notesToFetch,
    required this.notesToDeleteLocally,
    required this.tombstonesToSend,
  });
}

class SyncEngine {
  /// Compares local manifest with peer manifest to calculate bidirectional sync delta
  static SyncDelta calculateDelta({
    required SyncManifest localManifest,
    required SyncManifest peerManifest,
  }) {
    final Map<String, SyncNoteHeader> localMap = {
      for (final n in localManifest.notes) n.id: n,
    };
    final Map<String, SyncNoteHeader> peerMap = {
      for (final n in peerManifest.notes) n.id: n,
    };

    final List<String> notesToSend = [];
    final List<String> notesToFetch = [];
    final List<String> notesToDeleteLocally = [];
    final List<String> tombstonesToSend = [];

    // 1. Process all peer notes
    for (final peerHeader in peerManifest.notes) {
      final localHeader = localMap[peerHeader.id];

      if (localHeader == null) {
        // Peer has a note we don't have
        if (peerHeader.isDeleted) {
          // It's a tombstone we don't know about yet
          notesToDeleteLocally.add(peerHeader.id);
        } else {
          // It's an active note we need to download
          notesToFetch.add(peerHeader.id);
        }
      } else {
        // Both devices know this note
        if (peerHeader.isDeleted && !localHeader.isDeleted) {
          // Peer deleted it
          if (peerHeader.modifiedAt >= localHeader.modifiedAt) {
            notesToDeleteLocally.add(peerHeader.id);
          } else {
            // Local was modified AFTER peer deleted it -> revive on peer
            notesToSend.add(localHeader.id);
          }
        } else if (!peerHeader.isDeleted && localHeader.isDeleted) {
          // Local deleted it
          if (localHeader.modifiedAt >= peerHeader.modifiedAt) {
            tombstonesToSend.add(localHeader.id);
          } else {
            // Peer modified it AFTER local deleted it -> revive locally
            notesToFetch.add(peerHeader.id);
          }
        } else if (!peerHeader.isDeleted && !localHeader.isDeleted) {
          // Both active: compare timestamps
          if (peerHeader.modifiedAt > localHeader.modifiedAt) {
            notesToFetch.add(peerHeader.id);
          } else if (localHeader.modifiedAt > peerHeader.modifiedAt) {
            notesToSend.add(localHeader.id);
          }
        }
      }
    }

    // 2. Process local notes that peer doesn't have at all
    for (final localHeader in localManifest.notes) {
      if (!peerMap.containsKey(localHeader.id)) {
        if (localHeader.isDeleted) {
          tombstonesToSend.add(localHeader.id);
        } else {
          notesToSend.add(localHeader.id);
        }
      }
    }

    return SyncDelta(
      notesToSend: notesToSend,
      notesToFetch: notesToFetch,
      notesToDeleteLocally: notesToDeleteLocally,
      tombstonesToSend: tombstonesToSend,
    );
  }

  /// Resolves conflicts when merging note documents
  static NoteDocument? resolveConflict(NoteDocument local, NoteDocument incoming) {
    if (incoming.metadata.modifiedAt.isAfter(local.metadata.modifiedAt)) {
      return incoming;
    }
    return local;
  }
}
