import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Seamless WYSIWYG Rich Text Controller for Flutter
/// Directly renders Bold, Italic, Strikethrough, Bullets, and Checklists in real-time
/// by styling formatted text and making delimiter syntax visually invisible
class MarkdownRichTextController extends TextEditingController {
  TextStyle baseStyle;

  MarkdownRichTextController({
    super.text,
    required this.baseStyle,
  });

  static const TextStyle _hiddenStyle = TextStyle(
    fontSize: 0.001,
    color: Colors.transparent,
    letterSpacing: -1.0,
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final effectiveStyle = style ?? baseStyle;
    final textVal = text;

    if (textVal.isEmpty) {
      return TextSpan(style: effectiveStyle, text: textVal);
    }

    final List<InlineSpan> children = [];
    final lines = textVal.split('\n');

    for (int lineIdx = 0; lineIdx < lines.length; lineIdx++) {
      final line = lines[lineIdx];
      _parseLine(line, effectiveStyle, children);

      if (lineIdx < lines.length - 1) {
        children.add(const TextSpan(text: '\n'));
      }
    }

    return TextSpan(style: effectiveStyle, children: children);
  }

  void _parseLine(String line, TextStyle effectiveStyle, List<InlineSpan> children) {
    if (line.isEmpty) return;

    int prefixOffset = 0;
    TextStyle lineBaseStyle = effectiveStyle;

    // 1. Line Prefix Parsing (Heading, Bullet, Checklist, Quote)
    if (line.startsWith('# ')) {
      children.add(const TextSpan(text: '# ', style: _hiddenStyle));
      lineBaseStyle = effectiveStyle.copyWith(fontSize: (effectiveStyle.fontSize ?? 17) * 1.5, fontWeight: FontWeight.w900);
      prefixOffset = 2;
    } else if (line.startsWith('## ')) {
      children.add(const TextSpan(text: '## ', style: _hiddenStyle));
      lineBaseStyle = effectiveStyle.copyWith(fontSize: (effectiveStyle.fontSize ?? 17) * 1.3, fontWeight: FontWeight.bold);
      prefixOffset = 3;
    } else if (line.startsWith('### ')) {
      children.add(const TextSpan(text: '### ', style: _hiddenStyle));
      lineBaseStyle = effectiveStyle.copyWith(fontSize: (effectiveStyle.fontSize ?? 17) * 1.15, fontWeight: FontWeight.w700);
      prefixOffset = 4;
    } else if (line.startsWith('- ') || line.startsWith('* ')) {
      // Render clean bullet symbol instead of raw markdown
      children.add(TextSpan(text: line.substring(0, 2), style: _hiddenStyle));
      children.add(const TextSpan(text: '• ', style: TextStyle(color: AppColors.samsungOrange, fontWeight: FontWeight.bold)));
      prefixOffset = 2;
    } else if (line.startsWith('[ ] ')) {
      children.add(TextSpan(text: line.substring(0, 4), style: _hiddenStyle));
      children.add(const TextSpan(text: '☐ ', style: TextStyle(color: Colors.white60, fontWeight: FontWeight.bold)));
      prefixOffset = 4;
    } else if (line.startsWith('[x] ') || line.startsWith('[X] ')) {
      children.add(TextSpan(text: line.substring(0, 4), style: _hiddenStyle));
      children.add(const TextSpan(text: '☑ ', style: TextStyle(color: AppColors.samsungOrange, fontWeight: FontWeight.bold)));
      lineBaseStyle = lineBaseStyle.copyWith(color: Colors.white38, decoration: TextDecoration.lineThrough);
      prefixOffset = 4;
    } else if (line.startsWith('> ')) {
      children.add(TextSpan(text: line.substring(0, 2), style: _hiddenStyle));
      children.add(const TextSpan(text: '▎ ', style: TextStyle(color: AppColors.samsungOrange, fontWeight: FontWeight.bold)));
      lineBaseStyle = lineBaseStyle.copyWith(color: const Color(0xFFCCCCCC), fontStyle: FontStyle.italic);
      prefixOffset = 2;
    }

    final content = line.substring(prefixOffset);
    _parseInlineFormatting(content, lineBaseStyle, children);
  }

  void _parseInlineFormatting(String text, TextStyle currentStyle, List<InlineSpan> children) {
    if (text.isEmpty) return;

    // Match bold (**text**), italic (*text*), strikethrough (~~text~~), code (`text`)
    final regex = RegExp(r'(\*\*(.*?)\*\*|\*(.*?)\*|~~(.*?)~~|`(.*?)`)');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        children.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: currentStyle,
        ));
      }

      final fullMatch = match.group(0)!;

      if (fullMatch.startsWith('**') && fullMatch.endsWith('**') && fullMatch.length >= 4) {
        // Bold: Hide '**' delimiters and render inner text in Bold
        children.add(const TextSpan(text: '**', style: _hiddenStyle));
        children.add(TextSpan(
          text: fullMatch.substring(2, fullMatch.length - 2),
          style: currentStyle.copyWith(fontWeight: FontWeight.w900, color: Colors.white),
        ));
        children.add(const TextSpan(text: '**', style: _hiddenStyle));
      } else if (fullMatch.startsWith('~~') && fullMatch.endsWith('~~') && fullMatch.length >= 4) {
        // Strikethrough: Hide '~~' delimiters and render with lineThrough
        children.add(const TextSpan(text: '~~', style: _hiddenStyle));
        children.add(TextSpan(
          text: fullMatch.substring(2, fullMatch.length - 2),
          style: currentStyle.copyWith(decoration: TextDecoration.lineThrough, color: Colors.white70),
        ));
        children.add(const TextSpan(text: '~~', style: _hiddenStyle));
      } else if (fullMatch.startsWith('*') && fullMatch.endsWith('*') && fullMatch.length >= 2) {
        // Italic: Hide '*' delimiters and render in Italic
        children.add(const TextSpan(text: '*', style: _hiddenStyle));
        children.add(TextSpan(
          text: fullMatch.substring(1, fullMatch.length - 1),
          style: currentStyle.copyWith(fontStyle: FontStyle.italic),
        ));
        children.add(const TextSpan(text: '*', style: _hiddenStyle));
      } else if (fullMatch.startsWith('`') && fullMatch.endsWith('`') && fullMatch.length >= 2) {
        // Inline code
        children.add(const TextSpan(text: '`', style: _hiddenStyle));
        children.add(TextSpan(
          text: fullMatch.substring(1, fullMatch.length - 1),
          style: currentStyle.copyWith(
            fontFamily: 'monospace',
            backgroundColor: const Color(0xFF222222),
            color: AppColors.samsungOrange,
          ),
        ));
        children.add(const TextSpan(text: '`', style: _hiddenStyle));
      }

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      children.add(TextSpan(
        text: text.substring(lastEnd),
        style: currentStyle,
      ));
    }
  }
}
