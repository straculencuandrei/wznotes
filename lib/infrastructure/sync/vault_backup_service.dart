import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../domain/models/note_document.dart';

class VaultBackupResult {
  final bool success;
  final String message;
  final String? filePath;
  final int noteCount;

  VaultBackupResult({
    required this.success,
    required this.message,
    this.filePath,
    this.noteCount = 0,
  });
}

/// Offline & Cloud-Friendly Single-File Vault Backup and Restore (.wzbackup)
class VaultBackupService {
  /// Packages all notes into a single `.wzbackup` compressed archive
  static Future<VaultBackupResult> exportVault({
    required List<NoteDocument> notes,
    required String deviceName,
  }) async {
    try {
      if (notes.isEmpty) {
        return VaultBackupResult(
          success: false,
          message: 'No notes to export in vault.',
        );
      }

      final Archive archive = Archive();

      // 1. Vault manifest
      final manifestJson = json.encode({
        'app': 'wznotes',
        'format': 'WZNotes Vault Backup',
        'version': 1,
        'createdAt': DateTime.now().toIso8601String(),
        'deviceName': deviceName,
        'noteCount': notes.length,
      });
      final manifestBytes = utf8.encode(manifestJson);
      archive.addFile(ArchiveFile('vault_manifest.json', manifestBytes.length, manifestBytes));

      // 2. Individual note files
      for (final note in notes) {
        final noteJson = json.encode(note.toJson());
        final noteBytes = utf8.encode(noteJson);
        archive.addFile(ArchiveFile('notes/${note.metadata.id}.json', noteBytes.length, noteBytes));
      }

      final ZipEncoder encoder = ZipEncoder();
      final compressedBytes = encoder.encode(archive);
      if (compressedBytes == null) {
        return VaultBackupResult(success: false, message: 'Compression failed.');
      }

      // Determine save folder
      Directory? outDir;
      if (Platform.isAndroid) {
        // Public Documents or External Storage
        outDir = Directory('/storage/emulated/0/Documents/WZNotes');
        if (!outDir.existsSync()) {
          try {
            outDir.createSync(recursive: true);
          } catch (_) {
            outDir = await getExternalStorageDirectory();
          }
        }
      } else {
        outDir = await getApplicationDocumentsDirectory();
      }

      outDir ??= await getTemporaryDirectory();

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'wznotes_vault_$timestamp.wzbackup';
      final file = File(p.join(outDir.path, fileName));
      await file.writeAsBytes(compressedBytes, flush: true);

      return VaultBackupResult(
        success: true,
        message: 'Saved ${notes.length} notes to ${p.basename(file.path)}',
        filePath: file.path,
        noteCount: notes.length,
      );
    } catch (e) {
      return VaultBackupResult(
        success: false,
        message: 'Export failed: $e',
      );
    }
  }

  /// Restores notes from a `.wzbackup` compressed archive
  static Future<List<NoteDocument>> importVaultFromFile(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final ZipDecoder decoder = ZipDecoder();
      final archive = decoder.decodeBytes(bytes);

      final List<NoteDocument> imported = [];

      for (final archiveFile in archive) {
        if (archiveFile.name.startsWith('notes/') && archiveFile.name.endsWith('.json')) {
          final content = utf8.decode(archiveFile.content as List<int>);
          final jsonMap = json.decode(content) as Map<String, dynamic>;
          final doc = NoteDocument.fromJson(jsonMap);
          imported.add(doc);
        }
      }

      return imported;
    } catch (_) {
      return [];
    }
  }
}
