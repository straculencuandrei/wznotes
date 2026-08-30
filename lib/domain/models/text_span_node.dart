import 'package:flutter/material.dart';

/// Single formatted text run within a block
class TextSpanNode {
  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;
  final bool isCode;
  final Color? color;
  final Color? highlightColor;

  const TextSpanNode({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
    this.isCode = false,
    this.color,
    this.highlightColor,
  });

  TextSpan toTextSpan({TextStyle? baseStyle}) {
    TextStyle style = baseStyle ?? const TextStyle();
    if (bold) style = style.copyWith(fontWeight: FontWeight.bold);
    if (italic) style = style.copyWith(fontStyle: FontStyle.italic);
    if (color != null) style = style.copyWith(color: color);
    if (isCode) {
      style = style.copyWith(
        fontFamily: 'monospace',
        backgroundColor: const Color(0x1F64748B),
      );
    }
    if (highlightColor != null) {
      style = style.copyWith(backgroundColor: highlightColor);
    }

    TextDecoration decoration = TextDecoration.none;
    if (underline && strikethrough) {
      decoration = TextDecoration.combine([TextDecoration.underline, TextDecoration.lineThrough]);
    } else if (underline) {
      decoration = TextDecoration.underline;
    } else if (strikethrough) {
      decoration = TextDecoration.lineThrough;
    }
    style = style.copyWith(decoration: decoration);

    return TextSpan(text: text, style: style);
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        if (bold) 'bold': true,
        if (italic) 'italic': true,
        if (underline) 'underline': true,
        if (strikethrough) 'strikethrough': true,
        if (isCode) 'isCode': true,
        if (color != null) 'color': '#${color!.value.toRadixString(16).padLeft(8, '0')}',
        if (highlightColor != null) 'highlightColor': '#${highlightColor!.value.toRadixString(16).padLeft(8, '0')}',
      };

  factory TextSpanNode.fromJson(Map<String, dynamic> json) {
    Color? col;
    if (json['color'] != null) {
      col = Color(int.parse((json['color'] as String).replaceAll('#', ''), radix: 16));
    }
    Color? hl;
    if (json['highlightColor'] != null) {
      hl = Color(int.parse((json['highlightColor'] as String).replaceAll('#', ''), radix: 16));
    }

    return TextSpanNode(
      text: json['text'] as String? ?? '',
      bold: json['bold'] as bool? ?? false,
      italic: json['italic'] as bool? ?? false,
      underline: json['underline'] as bool? ?? false,
      strikethrough: json['strikethrough'] as bool? ?? false,
      isCode: json['isCode'] as bool? ?? false,
      color: col,
      highlightColor: hl,
    );
  }
}
