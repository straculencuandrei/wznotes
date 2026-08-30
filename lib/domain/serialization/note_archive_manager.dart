import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import '../models/note_document.dart';
import '../models/text_block.dart';
import '../models/vector_stroke.dart';
import '../models/canvas_template.dart';
import 'stroke_binary_codec.dart';
import 'note_json_codec.dart';

/// Manages packaging and extraction of `.note` ZIP archives
class NoteArchiveManager {
  /// Packages a complete NoteDocument into a compressed `.note` ZIP byte stream
  static Uint8List packageNoteToZip(NoteDocument doc, {Map<String, Uint8List>? assets}) {
    final Archive archive = Archive();

    // 1. metadata.json
    final String metadataJson = NoteJsonCodec.encodeMetadata(doc.metadata);
    final List<int> metaBytes = utf8.encode(metadataJson);
    archive.addFile(ArchiveFile('metadata.json', metaBytes.length, metaBytes));

    // 2. manifest.json
    final String manifestJson = json.encode({
      'format': 'OpenNotes Archive',
      'version': 1,
      'app': 'OpenNotes Cross-Platform',
      'createdAt': doc.metadata.createdAt.toIso8601String(),
    });
    final List<int> manifestBytes = utf8.encode(manifestJson);
    archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

    // 3. template.json
    final String templateJson = NoteJsonCodec.encodeTemplate(doc.template);
    final List<int> templateBytes = utf8.encode(templateJson);
    archive.addFile(ArchiveFile('template.json', templateBytes.length, templateBytes));

    // 4. document.json (Block-based rich text stream)
    final String documentJson = NoteJsonCodec.encodeDocumentBlocks(doc.blocks);
    final List<int> docBytes = utf8.encode(documentJson);
    archive.addFile(ArchiveFile('document.json', docBytes.length, docBytes));

    // 5. strokes.bin (High-performance packed binary)
    final Uint8List strokesBin = StrokeBinaryCodec.encode(doc.strokes);
    archive.addFile(ArchiveFile('strokes.bin', strokesBin.length, strokesBin));

    // 6. strokes.json (Interoperable human-readable JSON backup)
    final String strokesJson = NoteJsonCodec.encodeStrokesJson(doc.strokes);
    final List<int> strokesJsonBytes = utf8.encode(strokesJson);
    archive.addFile(ArchiveFile('strokes.json', strokesJsonBytes.length, strokesJsonBytes));

    // 7. assets/ folder (audio files, embedded images)
    if (assets != null) {
      for (final entry in assets.entries) {
        final path = entry.key.startsWith('assets/') ? entry.key : 'assets/${entry.key}';
        archive.addFile(ArchiveFile(path, entry.value.length, entry.value));
      }
    }

    // Zip encoding with ZipEncoder
    final ZipEncoder encoder = ZipEncoder();
    final List<int>? compressed = encoder.encode(archive);
    return Uint8List.fromList(compressed ?? []);
  }

  /// Extracts a NoteDocument from a `.note` ZIP byte stream
  static NoteDocument extractNoteFromZip(Uint8List zipBytes, {Map<String, Uint8List>? outAssets}) {
    final ZipDecoder decoder = ZipDecoder();
    final Archive archive = decoder.decodeBytes(zipBytes);

    NoteMetadata metadata = NoteMetadata.initial(title: 'Imported Note');
    List<TextBlock> blocks = [];
    List<VectorStroke> strokes = [];
    CanvasTemplate template = const CanvasTemplate();

    for (final ArchiveFile file in archive) {
      if (file.isFile) {
        final String name = file.name;
        final Uint8List content = file.content as Uint8List;

        if (name == 'metadata.json') {
          final String str = utf8.decode(content);
          metadata = NoteJsonCodec.decodeMetadata(str);
        } else if (name == 'template.json') {
          final String str = utf8.decode(content);
          template = NoteJsonCodec.decodeTemplate(str);
        } else if (name == 'document.json') {
          final String str = utf8.decode(content);
          blocks = NoteJsonCodec.decodeDocumentBlocks(str);
        } else if (name == 'strokes.bin') {
          try {
            strokes = StrokeBinaryCodec.decode(content);
          } catch (_) {
            // Fallback will check strokes.json if binary decoding has an issue
          }
        } else if (name == 'strokes.json' && strokes.isEmpty) {
          final String str = utf8.decode(content);
          strokes = NoteJsonCodec.decodeStrokesJson(str);
        } else if (name.startsWith('assets/') && outAssets != null) {
          outAssets[name.replaceFirst('assets/', '')] = content;
        }
      }
    }

    return NoteDocument(
      metadata: metadata,
      template: template,
      blocks: blocks,
      strokes: strokes,
    ).recalculateStats();
  }

  /// Saves note directly to file system (.note)
  static Future<void> saveToFile(NoteDocument doc, String filePath, {Map<String, Uint8List>? assets}) async {
    final Uint8List zipBytes = packageNoteToZip(doc, assets: assets);
    final File file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(zipBytes, flush: true);
  }

  /// Reads note directly from file system (.note)
  static Future<NoteDocument> loadFromFile(String filePath, {Map<String, Uint8List>? outAssets}) async {
    final File file = File(filePath);
    final Uint8List zipBytes = await file.readAsBytes();
    return extractNoteFromZip(zipBytes, outAssets: outAssets);
  }
}
