import 'dart:convert';
import '../models/note_document.dart';
import '../models/text_block.dart';
import '../models/vector_stroke.dart';
import '../models/canvas_template.dart';

/// JSON Serializer and Parser for open `.note` JSON schema
class NoteJsonCodec {
  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  /// Serializes metadata to JSON string
  static String encodeMetadata(NoteMetadata metadata) {
    return _encoder.convert(metadata.toJson());
  }

  /// Parses metadata from JSON string
  static NoteMetadata decodeMetadata(String jsonString) {
    final Map<String, dynamic> map = json.decode(jsonString) as Map<String, dynamic>;
    return NoteMetadata.fromJson(map);
  }

  /// Serializes text blocks to `document.json` string
  static String encodeDocumentBlocks(List<TextBlock> blocks) {
    return _encoder.convert({
      'version': 1,
      'blocks': blocks.map((b) => b.toJson()).toList(),
    });
  }

  /// Parses text blocks from `document.json` string
  static List<TextBlock> decodeDocumentBlocks(String jsonString) {
    final Map<String, dynamic> map = json.decode(jsonString) as Map<String, dynamic>;
    final List<dynamic> blocksList = map['blocks'] as List<dynamic>? ?? [];
    return blocksList.map((b) => TextBlock.fromJson(b as Map<String, dynamic>)).toList();
  }

  /// Serializes vector strokes to `strokes.json` string
  static String encodeStrokesJson(List<VectorStroke> strokes) {
    return _encoder.convert({
      'version': 1,
      'strokes': strokes.map((s) => s.toJson()).toList(),
    });
  }

  /// Parses vector strokes from `strokes.json` string
  static List<VectorStroke> decodeStrokesJson(String jsonString) {
    final Map<String, dynamic> map = json.decode(jsonString) as Map<String, dynamic>;
    final List<dynamic> list = map['strokes'] as List<dynamic>? ?? [];
    return list.map((s) => VectorStroke.fromJson(s as Map<String, dynamic>)).toList();
  }

  /// Serializes template configuration
  static String encodeTemplate(CanvasTemplate template) {
    return _encoder.convert(template.toJson());
  }

  /// Parses template configuration
  static CanvasTemplate decodeTemplate(String jsonString) {
    final Map<String, dynamic> map = json.decode(jsonString) as Map<String, dynamic>;
    return CanvasTemplate.fromJson(map);
  }
}
