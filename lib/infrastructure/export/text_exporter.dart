import '../../domain/models/note_document.dart';
import '../../domain/models/text_block.dart';

/// Exports structured rich text notes to clean plain text (.txt)
class TextExporter {
  static String exportToPlainText(NoteDocument doc) {
    final StringBuffer buffer = StringBuffer();

    // Document Title
    final title = doc.metadata.title.trim().isNotEmpty
        ? doc.metadata.title.trim()
        : 'Untitled Note';
    buffer.writeln(title);
    buffer.writeln('=' * title.length.clamp(1, 40));
    buffer.writeln();

    if (doc.blocks.isEmpty && doc.strokes.isNotEmpty) {
      buffer.writeln('[Handwritten Inking Note - ${doc.strokes.length} vector inking stroke(s)]');
      return buffer.toString().trimRight();
    }

    int numberedIndex = 1;

    for (final block in doc.blocks) {
      final text = block.rawText;
      switch (block.type) {
        case TextBlockType.heading1:
          numberedIndex = 1;
          buffer.writeln();
          buffer.writeln(text.toUpperCase());
          buffer.writeln('-' * text.length.clamp(1, 40));
          break;
        case TextBlockType.heading2:
          numberedIndex = 1;
          buffer.writeln();
          buffer.writeln(text);
          buffer.writeln('-' * text.length.clamp(1, 30));
          break;
        case TextBlockType.heading3:
          numberedIndex = 1;
          buffer.writeln();
          buffer.writeln(text);
          break;
        case TextBlockType.paragraph:
          numberedIndex = 1;
          buffer.writeln(text);
          break;
        case TextBlockType.bulletList:
          numberedIndex = 1;
          buffer.writeln('• $text');
          break;
        case TextBlockType.numberedList:
          buffer.writeln('$numberedIndex. $text');
          numberedIndex++;
          break;
        case TextBlockType.checklist:
          numberedIndex = 1;
          final check = block.isChecked ? '[x]' : '[ ]';
          buffer.writeln('$check $text');
          break;
        case TextBlockType.blockquote:
          numberedIndex = 1;
          buffer.writeln('  | $text');
          break;
        case TextBlockType.codeBlock:
          numberedIndex = 1;
          buffer.writeln('--- CODE ${block.codeLanguage ?? ""} ---');
          buffer.writeln(text);
          buffer.writeln('--- END CODE ---');
          break;
      }
    }

    return buffer.toString().trimRight();
  }
}
