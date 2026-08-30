import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../domain/models/note_document.dart';
import '../../infrastructure/export/markdown_exporter.dart';
import '../../infrastructure/export/pdf_exporter.dart';
import '../../infrastructure/export/svg_exporter.dart';
import '../controllers/document_controller.dart';
import '../controllers/notes_library_controller.dart';
import '../controllers/inking_controller.dart';
import '../canvas/infinite_canvas_viewport.dart';
import '../widgets/text_formatting_toolbar.dart';
import '../widgets/floating_pen_dock.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _saveAndPop() {
    final currentDoc = ref.read(documentProvider);
    ref.read(notesLibraryProvider.notifier).saveNote(currentDoc);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final doc = ref.watch(documentProvider);
    final inkingState = ref.watch(inkingProvider);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          final currentDoc = ref.read(documentProvider);
          ref.read(notesLibraryProvider.notifier).saveNote(currentDoc);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.amoledBlack,
        appBar: AppBar(
          backgroundColor: AppColors.amoledBlack,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 22, color: Colors.white),
            tooltip: 'Back to Notes',
            onPressed: _saveAndPop,
          ),
          title: Text(
            doc.metadata.wordCount > 0 ? '${doc.metadata.wordCount} words' : '',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.amoledTextSecondary,
            ),
          ),
          centerTitle: false,
          actions: [
            // Export & Options Menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 24, color: Colors.white),
              tooltip: 'Note Options',
              color: AppColors.amoledSurfaceElevated,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.amoledBorder),
              ),
              onSelected: (action) {
                if (action == 'delete') {
                  _confirmDelete(context, doc);
                } else {
                  _handleExport(context, action, doc);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'pdf',
                  child: Text('Export to Vector PDF', style: TextStyle(color: Colors.white, fontSize: 14)),
                ),
                const PopupMenuItem(
                  value: 'markdown',
                  child: Text('Export to Markdown (.md)', style: TextStyle(color: Colors.white, fontSize: 14)),
                ),
                const PopupMenuItem(
                  value: 'svg',
                  child: Text('Export to SVG Vector', style: TextStyle(color: Colors.white, fontSize: 14)),
                ),
                const PopupMenuDivider(height: 1),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: AppColors.accentRose, size: 20),
                      SizedBox(width: 8),
                      Text('Delete note', style: TextStyle(color: AppColors.accentRose, fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            // 1. Full AMOLED Keyboard Writing Viewport
            Expanded(
              child: InfiniteCanvasViewport(scrollController: _scrollController),
            ),

            // 2. Optional Floating Stylus Tool Dock (Only shown when drawing mode is toggled on)
            if (inkingState.isInkingMode)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: FloatingPenDock(),
              ),

            // 3. Samsung Notes Style Bottom Keyboard Accessory Bar (Always Accessible)
            const TextFormattingToolbar(),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, NoteDocument doc) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.amoledSurfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.amoledBorder),
        ),
        title: const Text('Delete this note?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'This note will be permanently deleted.',
          style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              ref.read(notesLibraryProvider.notifier).deleteNote(doc.metadata.id);
              Navigator.of(context).pop(); // dismiss dialog
              Navigator.of(context).pop(); // exit editor
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.accentRose, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleExport(BuildContext context, String format, NoteDocument doc) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exporting note to ${format.toUpperCase()}...'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.amoledSurfaceElevated,
      ),
    );

    if (format == 'markdown') {
      final md = MarkdownExporter.exportToMarkdown(doc);
      _showExportPreview(context, 'Markdown Export', md);
    } else if (format == 'svg') {
      final svg = SvgExporter.exportToSvg(doc);
      _showExportPreview(context, 'SVG Vector Export', svg);
    } else if (format == 'pdf') {
      final pdfBytes = await PdfExporter.exportToPdf(doc);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vector PDF generated (${pdfBytes.length} bytes)!'),
            backgroundColor: AppColors.accentEmerald,
          ),
        );
      }
    }
  }

  void _showExportPreview(BuildContext context, String title, String content) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.amoledSurfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.amoledBorder),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 600,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(
              content,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Color(0xFFE0E0E0)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(color: AppColors.samsungOrange, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
