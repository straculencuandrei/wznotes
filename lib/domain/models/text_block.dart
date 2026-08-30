import 'text_span_node.dart';

enum TextBlockType {
  paragraph,
  heading1,
  heading2,
  heading3,
  bulletList,
  numberedList,
  checklist,
  blockquote,
  codeBlock,
}

/// Structured rich text block in an unbounded infinite note
class TextBlock {
  final String id;
  final TextBlockType type;
  final String rawText;
  final List<TextSpanNode> spans;
  final bool isChecked; // For checklists
  final String? codeLanguage; // For code blocks
  final double estimatedHeight; // Precomputed layout height for virtualization

  const TextBlock({
    required this.id,
    required this.type,
    required this.rawText,
    this.spans = const [],
    this.isChecked = false,
    this.codeLanguage,
    this.estimatedHeight = 32.0,
  });

  TextBlock copyWith({
    String? id,
    TextBlockType? type,
    String? rawText,
    List<TextSpanNode>? spans,
    bool? isChecked,
    String? codeLanguage,
    double? estimatedHeight,
  }) {
    return TextBlock(
      id: id ?? this.id,
      type: type ?? this.type,
      rawText: rawText ?? this.rawText,
      spans: spans ?? this.spans,
      isChecked: isChecked ?? this.isChecked,
      codeLanguage: codeLanguage ?? this.codeLanguage,
      estimatedHeight: estimatedHeight ?? this.estimatedHeight,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'rawText': rawText,
        if (spans.isNotEmpty) 'spans': spans.map((s) => s.toJson()).toList(),
        if (type == TextBlockType.checklist) 'isChecked': isChecked,
        if (codeLanguage != null) 'codeLanguage': codeLanguage,
        'estimatedHeight': estimatedHeight,
      };

  factory TextBlock.fromJson(Map<String, dynamic> json) {
    return TextBlock(
      id: json['id'] as String,
      type: TextBlockType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => TextBlockType.paragraph,
      ),
      rawText: json['rawText'] as String? ?? '',
      spans: (json['spans'] as List?)
              ?.map((s) => TextSpanNode.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      isChecked: json['isChecked'] as bool? ?? false,
      codeLanguage: json['codeLanguage'] as String?,
      estimatedHeight: (json['estimatedHeight'] as num?)?.toDouble() ?? 32.0,
    );
  }
}
