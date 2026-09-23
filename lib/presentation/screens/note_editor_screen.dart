import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../domain/models/note_document.dart';
import '../../infrastructure/export/markdown_exporter.dart';
import '../../infrastructure/export/svg_exporter.dart';
import '../widgets/export_dialog.dart';
import '../widgets/infinite_rich_text_layer.dart';
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

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  bool _isDeleting = false;
  Timer? _autoSaveDebouncer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSaveDebouncer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      if (!_isDeleting) {
        _flushAndSave();
      }
    }
  }

  void _flushAndSave() {
    if (_isDeleting) return;
    InfiniteRichTextLayer.flushActive();
    final currentDoc = ref.read(documentProvider);
    ref.read(notesLibraryProvider.notifier).saveNote(currentDoc);
  }

  void _saveAndPop() {
    if (!_isDeleting) {
      _flushAndSave();
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final wordCount = ref.watch(documentProvider.select((d) => d.metadata.wordCount));
    final inkingState = ref.watch(inkingProvider);

    // Auto-save: When document content updates, debounce save to disk within 2s
    ref.listen<NoteDocument>(documentProvider, (previous, next) {
      if (_isDeleting) return;
      _autoSaveDebouncer?.cancel();
      _autoSaveDebouncer = Timer(const Duration(milliseconds: 2000), () {
        if (mounted && !_isDeleting) {
          ref.read(notesLibraryProvider.notifier).saveNote(next);
        }
      });
    });

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_isDeleting) {
          _flushAndSave();
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
            wordCount > 0 ? '$wordCount words' : '',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.amoledTextSecondary,
            ),
          ),
          centerTitle: false,
          actions: [
            // Quick direct delete button inside note header
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 22, color: AppColors.accentRose),
              tooltip: 'Delete Note',
              onPressed: () {
                final currentDoc = ref.read(documentProvider);
                _confirmDelete(context, currentDoc);
              },
            ),

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
                final currentDoc = ref.read(documentProvider);
                if (action == 'delete') {
                  _confirmDelete(context, currentDoc);
                } else {
                  _handleExport(context, action, currentDoc);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'txt',
                  child: Row(
                    children: [
                      Icon(Icons.article_outlined, color: Colors.blueAccent, size: 18),
                      SizedBox(width: 8),
                      Text('Export to Plain Text (.txt)', style: TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'pdf',
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf_outlined, color: AppColors.accentRose, size: 18),
                      SizedBox(width: 8),
                      Text('Export to Vector PDF (.pdf)', style: TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'markdown',
                  child: Row(
                    children: [
                      Icon(Icons.code_rounded, color: Colors.white70, size: 18),
                      SizedBox(width: 8),
                      Text('Export to Markdown (.md)', style: TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'svg',
                  child: Row(
                    children: [
                      Icon(Icons.draw_outlined, color: AppColors.samsungOrange, size: 18),
                      SizedBox(width: 8),
                      Text('Export to SVG Vector', style: TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
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
      builder: (dialogCtx) => AlertDialog(
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
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              _isDeleting = true;
              _autoSaveDebouncer?.cancel();
              ref.read(notesLibraryProvider.notifier).deleteNote(doc.metadata.id);
              Navigator.of(dialogCtx).pop(); // dismiss dialog
              Navigator.of(context).pop(); // exit editor
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.accentRose, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExport(BuildContext context, String format, NoteDocument doc) async {
    if (format == 'txt') {
      await NoteExportService.exportSingleNote(context, doc, format: ExportFormat.txt);
    } else if (format == 'pdf') {
      await NoteExportService.exportSingleNote(context, doc, format: ExportFormat.pdf);
    } else if (format == 'markdown') {
      final md = MarkdownExporter.exportToMarkdown(doc);
      _showExportPreview(context, 'Markdown Export', md);
    } else if (format == 'svg') {
      final svg = SvgExporter.exportToSvg(doc);
      _showExportPreview(context, 'SVG Vector Export', svg);
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
