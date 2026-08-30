import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as p;
import '../../domain/models/note_document.dart';

/// SQLite Database Manager with FTS5 Full-Text Search and Metadata Indexing
class AppDatabase {
  late final Database _db;

  AppDatabase._(this._db);

  static Future<AppDatabase> open(String directoryPath) async {
    final dbFile = File(p.join(directoryPath, 'opennotes.db'));
    if (!dbFile.parent.existsSync()) {
      dbFile.parent.createSync(recursive: true);
    }

    final db = sqlite3.open(dbFile.path);
    final appDb = AppDatabase._(db);
    appDb._initSchema();
    return appDb;
  }

  void _initSchema() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS notebooks (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color TEXT DEFAULT '#3B82F6',
        created_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS notes (
        id TEXT PRIMARY KEY,
        notebook_id TEXT,
        title TEXT NOT NULL,
        archive_path TEXT NOT NULL,
        word_count INTEGER DEFAULT 0,
        character_count INTEGER DEFAULT 0,
        reading_time_min INTEGER DEFAULT 0,
        total_height REAL DEFAULT 4000.0,
        has_audio INTEGER DEFAULT 0,
        is_pinned INTEGER DEFAULT 0,
        is_favorite INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS tags (
        id TEXT PRIMARY KEY,
        name TEXT UNIQUE NOT NULL
      );

      CREATE TABLE IF NOT EXISTS note_tags (
        note_id TEXT REFERENCES notes(id) ON DELETE CASCADE,
        tag_id TEXT REFERENCES tags(id) ON DELETE CASCADE,
        PRIMARY KEY (note_id, tag_id)
      );

      -- FTS5 Full-Text Search Virtual Table for fast search on huge notes
      CREATE VIRTUAL TABLE IF NOT EXISTS note_search_fts USING fts5(
        note_id UNINDEXED,
        title,
        body_text,
        tokenize='porter unicode61'
      );
    ''');
  }

  /// Inserts or updates a note's index record and FTS5 body text
  void upsertNote(NoteDocument doc, String archivePath) {
    final int now = DateTime.now().millisecondsSinceEpoch;

    final stmt = _db.prepare('''
      INSERT INTO notes (
        id, notebook_id, title, archive_path, word_count,
        character_count, reading_time_min, total_height, has_audio,
        created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        title = excluded.title,
        archive_path = excluded.archive_path,
        word_count = excluded.word_count,
        character_count = excluded.character_count,
        reading_time_min = excluded.reading_time_min,
        total_height = excluded.total_height,
        has_audio = excluded.has_audio,
        updated_at = excluded.updated_at
    ''');

    stmt.execute([
      doc.metadata.id,
      doc.metadata.folderId,
      doc.metadata.title,
      archivePath,
      doc.metadata.wordCount,
      doc.metadata.characterCount,
      doc.metadata.readingTimeMinutes,
      doc.metadata.totalHeight,
      doc.metadata.hasAudio ? 1 : 0,
      doc.metadata.createdAt.millisecondsSinceEpoch,
      now,
    ]);
    stmt.dispose();

    // Update FTS5 Search Index
    final ftsDelete = _db.prepare('DELETE FROM note_search_fts WHERE note_id = ?');
    ftsDelete.execute([doc.metadata.id]);
    ftsDelete.dispose();

    final allText = doc.blocks.map((b) => b.rawText).join('\n');
    final ftsInsert = _db.prepare('''
      INSERT INTO note_search_fts (note_id, title, body_text)
      VALUES (?, ?, ?)
    ''');
    ftsInsert.execute([doc.metadata.id, doc.metadata.title, allText]);
    ftsInsert.dispose();
  }

  /// Fast FTS5 Search across notes returning matching note IDs and snippets
  List<Map<String, dynamic>> searchNotes(String query) {
    if (query.trim().isEmpty) return [];

    final cleanQuery = query.replaceAll('"', '""');
    final stmt = _db.prepare('''
      SELECT note_id, title, snippet(note_search_fts, 2, '<b>', '</b>', '...', 15) as snippet
      FROM note_search_fts
      WHERE note_search_fts MATCH ?
      ORDER BY rank
      LIMIT 50
    ''');

    final result = stmt.select(['"$cleanQuery"*']);
    final list = result.map((row) => {
          'noteId': row['note_id'] as String,
          'title': row['title'] as String,
          'snippet': row['snippet'] as String,
        }).toList();

    stmt.dispose();
    return list;
  }

  /// Closes database connection
  void dispose() {
    _db.dispose();
  }
}
