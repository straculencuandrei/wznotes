import '../../domain/models/note_document.dart';
import '../../domain/models/text_block.dart';

/// Exports infinite rich text notes to standard Markdown (.md)
class MarkdownExporter {
  static String exportToMarkdown(NoteDocument doc) {
    final StringBuffer buffer = StringBuffer();

    // Document Title
    buffer.writeln('# ${doc.metadata.title}');
    buffer.writeln();
    buffer.writeln('> Created: ${doc.metadata.createdAt.toIso8601String()} | Words: ${doc.metadata.wordCount}');
    buffer.writeln();

    for (final block in doc.blocks) {
      switch (block.type) {
        case TextBlockType.heading1:
          buffer.writeln('# ${block.rawText}');
          buffer.writeln();
          break;
        case TextBlockType.heading2:
          buffer.writeln('## ${block.rawText}');
          buffer.writeln();
          break;
        case TextBlockType.heading3:
          buffer.writeln('### ${block.rawText}');
          buffer.writeln();
          break;
        case TextBlockType.paragraph:
          buffer.writeln(_formatSpans(block));
          buffer.writeln();
          break;
        case TextBlockType.bulletList:
          buffer.writeln('- ${_formatSpans(block)}');
          break;
        case TextBlockType.numberedList:
          buffer.writeln('1. ${_formatSpans(block)}');
          break;
        case TextBlockType.checklist:
          final check = block.isChecked ? '[x]' : '[ ]';
          buffer.writeln('- $check ${_formatSpans(block)}');
          break;
        case TextBlockType.blockquote:
          buffer.writeln('> ${_formatSpans(block)}');
          buffer.writeln();
          break;
        case TextBlockType.codeBlock:
          final lang = block.codeLanguage ?? '';
          buffer.writeln('```$lang');
          buffer.writeln(block.rawText);
          buffer.writeln('```');
          buffer.writeln();
          break;
      }
    }

    return buffer.toString();
  }

  static String _formatSpans(TextBlock block) {
    if (block.spans.isEmpty) return block.rawText;
    final sb = StringBuffer();
    for (final span in block.spans) {
      String text = span.text;
      if (span.isCode) text = '`$text`';
      if (span.bold && span.italic) {
        text = '***$text***';
      } else if (span.bold) {
        text = '**$text**';
      } else if (span.italic) {
        text = '*$text*';
      }
      if (span.strikethrough) text = '~~$text~~';
      if (span.highlightColor != null) text = '==$text==';
      sb.write(text);
    }
    return sb.toString();
  }
}
