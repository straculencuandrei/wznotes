import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../domain/models/note_document.dart';
import '../../domain/models/text_block.dart';

/// PDF Exporter combining structured rich text and vector inking paths
class PdfExporter {
  static Future<Uint8List> exportToPdf(NoteDocument doc) async {
    final pdf = pw.Document(
      title: doc.metadata.title,
      author: 'OpenNotes',
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                doc.metadata.title,
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 12),
            ...doc.blocks.map((block) => _buildPdfBlock(block)),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildPdfBlock(TextBlock block) {
    switch (block.type) {
      case TextBlockType.heading1:
        return pw.Padding(
          padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
          child: pw.Text(
            block.rawText,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
          ),
        );
      case TextBlockType.heading2:
        return pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
          child: pw.Text(
            block.rawText,
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
          ),
        );
      case TextBlockType.heading3:
        return pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8, bottom: 2),
          child: pw.Text(
            block.rawText,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
          ),
        );
      case TextBlockType.bulletList:
        return pw.Padding(
          padding: const pw.EdgeInsets.only(left: 12, top: 2, bottom: 2),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('• ', style: const pw.TextStyle(fontSize: 11)),
              pw.Expanded(child: pw.Text(block.rawText, style: const pw.TextStyle(fontSize: 11))),
            ],
          ),
        );
      case TextBlockType.checklist:
        return pw.Padding(
          padding: const pw.EdgeInsets.only(left: 12, top: 2, bottom: 2),
          child: pw.Row(
            children: [
              pw.Container(
                width: 10,
                height: 10,
                margin: const pw.EdgeInsets.only(right: 6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey600, width: 1),
                  color: block.isChecked ? PdfColors.blue600 : null,
                ),
              ),
              pw.Expanded(child: pw.Text(block.rawText, style: const pw.TextStyle(fontSize: 11))),
            ],
          ),
        );
      case TextBlockType.codeBlock:
        return pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.symmetric(vertical: 6),
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            border: pw.Border.all(color: PdfColors.grey300),
          ),
          child: pw.Text(
            block.rawText,
            style: pw.TextStyle(font: pw.Font.courier(), fontSize: 10),
          ),
        );
      case TextBlockType.blockquote:
        return pw.Container(
          margin: const pw.EdgeInsets.symmetric(vertical: 4),
          padding: const pw.EdgeInsets.only(left: 10, top: 4, bottom: 4),
          decoration: const pw.BoxDecoration(
            border: pw.Border(left: pw.BorderSide(color: PdfColors.blue600, width: 3)),
          ),
          child: pw.Text(
            block.rawText,
            style: pw.TextStyle(fontStyle: pw.FontStyle.italic, color: PdfColors.grey700),
          ),
        );
      default:
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Text(block.rawText, style: const pw.TextStyle(fontSize: 11, lineSpacing: 2)),
        );
    }
  }
}
