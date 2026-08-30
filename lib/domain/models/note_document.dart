import 'package:uuid/uuid.dart';
import '../../core/constants/canvas_dimensions.dart';
import 'text_block.dart';
import 'vector_stroke.dart';
import 'canvas_template.dart';
import 'document_outline.dart';

/// Note Metadata & Statistics
class NoteMetadata {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final List<String> tags;
  final String folderId;
  final int wordCount;
  final int characterCount;
  final int readingTimeMinutes;
  final double totalHeight;
  final bool hasAudio;
  final bool isLocked;
  final String? lockPin;

  const NoteMetadata({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.modifiedAt,
    this.tags = const [],
    this.folderId = 'root',
    this.wordCount = 0,
    this.characterCount = 0,
    this.readingTimeMinutes = 0,
    this.totalHeight = CanvasDimensions.initialInfiniteHeight,
    this.hasAudio = false,
    this.isLocked = false,
    this.lockPin,
  });

  NoteMetadata copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? modifiedAt,
    List<String>? tags,
    String? folderId,
    int? wordCount,
    int? characterCount,
    int? readingTimeMinutes,
    double? totalHeight,
    bool? hasAudio,
    bool? isLocked,
    String? lockPin,
  }) {
    return NoteMetadata(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      tags: tags ?? this.tags,
      folderId: folderId ?? this.folderId,
      wordCount: wordCount ?? this.wordCount,
      characterCount: characterCount ?? this.characterCount,
      readingTimeMinutes: readingTimeMinutes ?? this.readingTimeMinutes,
      totalHeight: totalHeight ?? this.totalHeight,
      hasAudio: hasAudio ?? this.hasAudio,
      isLocked: isLocked ?? this.isLocked,
      lockPin: lockPin ?? this.lockPin,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': modifiedAt.toIso8601String(),
        'tags': tags,
        'folderId': folderId,
        'wordCount': wordCount,
        'characterCount': characterCount,
        'readingTimeMinutes': readingTimeMinutes,
        'totalHeight': totalHeight,
        'hasAudio': hasAudio,
        'isLocked': isLocked,
        if (lockPin != null) 'lockPin': lockPin,
      };

  factory NoteMetadata.initial({String title = 'Untitled Note'}) {
    final now = DateTime.now();
    return NoteMetadata(
      id: const Uuid().v4(),
      title: title,
      createdAt: now,
      modifiedAt: now,
    );
  }

  factory NoteMetadata.fromJson(Map<String, dynamic> json) {
    return NoteMetadata(
      id: json['id'] as String? ?? const Uuid().v4(),
      title: json['title'] as String? ?? 'Untitled Note',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      modifiedAt: DateTime.tryParse(json['modifiedAt'] as String? ?? '') ?? DateTime.now(),
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      folderId: json['folderId'] as String? ?? 'root',
      wordCount: (json['wordCount'] as num?)?.toInt() ?? 0,
      characterCount: (json['characterCount'] as num?)?.toInt() ?? 0,
      readingTimeMinutes: (json['readingTimeMinutes'] as num?)?.toInt() ?? 0,
      totalHeight: (json['totalHeight'] as num?)?.toDouble() ?? CanvasDimensions.initialInfiniteHeight,
      hasAudio: json['hasAudio'] as bool? ?? false,
      isLocked: json['isLocked'] as bool? ?? false,
      lockPin: json['lockPin'] as String?,
    );
  }
}

/// Top-level Unbounded Note Document
class NoteDocument {
  final NoteMetadata metadata;
  final CanvasTemplate template;
  final List<TextBlock> blocks;
  final List<VectorStroke> strokes;

  const NoteDocument({
    required this.metadata,
    this.template = const CanvasTemplate(),
    this.blocks = const [],
    this.strokes = const [],
  });

  /// Computes auto-generated Table of Contents Outline
  List<OutlineHeading> generateOutline() {
    final List<OutlineHeading> outline = [];
    double currentY = 40.0;
    int currentSectionWords = 0;

    for (final block in blocks) {
      final int blockWords = _countWords(block.rawText);
      currentSectionWords += blockWords;

      if (block.type == TextBlockType.heading1) {
        outline.add(OutlineHeading(
          blockId: block.id,
          level: 1,
          title: block.rawText,
          estimatedYOffset: currentY,
          wordCountInSection: currentSectionWords,
        ));
      } else if (block.type == TextBlockType.heading2) {
        outline.add(OutlineHeading(
          blockId: block.id,
          level: 2,
          title: block.rawText,
          estimatedYOffset: currentY,
          wordCountInSection: currentSectionWords,
        ));
      } else if (block.type == TextBlockType.heading3) {
        outline.add(OutlineHeading(
          blockId: block.id,
          level: 3,
          title: block.rawText,
          estimatedYOffset: currentY,
          wordCountInSection: currentSectionWords,
        ));
      }
      currentY += block.estimatedHeight;
    }
    return outline;
  }

  /// Recalculates document statistics (word count, reading time)
  NoteDocument recalculateStats() {
    int totalWords = 0;
    int totalChars = 0;

    for (final b in blocks) {
      totalChars += b.rawText.length;
      totalWords += _countWords(b.rawText);
    }

    // 220 words per minute average reading speed
    final int readingTime = (totalWords / 220).ceil().clamp(1, 9999);

    final updatedMetadata = metadata.copyWith(
      wordCount: totalWords,
      characterCount: totalChars,
      readingTimeMinutes: totalWords > 0 ? readingTime : 0,
      modifiedAt: DateTime.now(),
    );

    return copyWith(metadata: updatedMetadata);
  }

  static int _countWords(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  NoteDocument copyWith({
    NoteMetadata? metadata,
    CanvasTemplate? template,
    List<TextBlock>? blocks,
    List<VectorStroke>? strokes,
  }) {
    return NoteDocument(
      metadata: metadata ?? this.metadata,
      template: template ?? this.template,
      blocks: blocks ?? this.blocks,
      strokes: strokes ?? this.strokes,
    );
  }

  Map<String, dynamic> toJson() => {
        'metadata': metadata.toJson(),
        'template': template.toJson(),
        'blocks': blocks.map((b) => b.toJson()).toList(),
        'strokes': strokes.map((s) => s.toJson()).toList(),
      };

  factory NoteDocument.fromJson(Map<String, dynamic> json) {
    return NoteDocument(
      metadata: NoteMetadata.fromJson(json['metadata'] as Map<String, dynamic>? ?? {}),
      template: CanvasTemplate.fromJson(json['template'] as Map<String, dynamic>? ?? {}),
      blocks: (json['blocks'] as List<dynamic>?)
              ?.map((b) => TextBlock.fromJson(b as Map<String, dynamic>))
              .toList() ??
          [],
      strokes: (json['strokes'] as List<dynamic>?)
              ?.map((s) => VectorStroke.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Creates a clean blank document
  factory NoteDocument.initial({String title = ''}) {
    final now = DateTime.now();
    return NoteDocument(
      metadata: NoteMetadata(
        id: const Uuid().v4(),
        title: title,
        createdAt: now,
        modifiedAt: now,
      ),
      template: const CanvasTemplate(type: CanvasTemplateType.blank),
      blocks: [
        const TextBlock(
          id: 'b1',
          type: TextBlockType.paragraph,
          rawText: '',
          estimatedHeight: 32.0,
        ),
      ],
      strokes: [],
    ).recalculateStats();
  }
}
