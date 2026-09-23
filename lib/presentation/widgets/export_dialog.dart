import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../core/constants/app_colors.dart';
import '../../domain/models/note_document.dart';
import '../../domain/serialization/note_archive_manager.dart';
import '../../infrastructure/export/pdf_exporter.dart';
import '../../infrastructure/export/text_exporter.dart';
import 'top_island_toast.dart';

enum ExportFormat {
  txt,
  pdf,
}

/// A sleek Samsung Notes / AMOLED styled modal dialog for choosing export format
class ExportChoiceDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final String confirmLabel;
  final ExportFormat initialFormat;

  const ExportChoiceDialog({
    super.key,
    required this.title,
    required this.subtitle,
    this.confirmLabel = 'Export',
    this.initialFormat = ExportFormat.txt,
  });

  static Future<ExportFormat?> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    String confirmLabel = 'Export',
    ExportFormat initialFormat = ExportFormat.txt,
  }) {
    return showModalBottomSheet<ExportFormat>(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      barrierColor: Colors.black54,
      isScrollControlled: true,
      builder: (ctx) => ExportChoiceDialog(
        title: title,
        subtitle: subtitle,
        confirmLabel: confirmLabel,
        initialFormat: initialFormat,
      ),
    );
  }

  @override
  State<ExportChoiceDialog> createState() => _ExportChoiceDialogState();
}

class _ExportChoiceDialogState extends State<ExportChoiceDialog> {
  late ExportFormat _selectedFormat;

  @override
  void initState() {
    super.initState();
    _selectedFormat = widget.initialFormat;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: const Color(0xFF2E2E2E), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title & Subtitle
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.samsungOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.file_download_outlined, color: AppColors.samsungOrange, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            color: AppColors.amoledTextSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // Option 1: Plain Text (.txt)
              _buildFormatOption(
                format: ExportFormat.txt,
                extension: '.txt',
                title: 'Plain Text Document',
                description: 'Universal, lightweight text without styling. Easy to read anywhere.',
                icon: Icons.article_outlined,
                badgeColor: Colors.blueAccent,
              ),

              const SizedBox(height: 12),

              // Option 2: Vector PDF (.pdf)
              _buildFormatOption(
                format: ExportFormat.pdf,
                extension: '.pdf',
                title: 'Vector PDF Document',
                description: 'Standard print-ready A4 document with styled headings and checklists.',
                icon: Icons.picture_as_pdf_outlined,
                badgeColor: AppColors.accentRose,
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Color(0xFF333333)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.samsungOrange,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => Navigator.of(context).pop(_selectedFormat),
                      child: Text(
                        '${widget.confirmLabel} (${_selectedFormat == ExportFormat.txt ? ".txt" : ".pdf"})',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormatOption({
    required ExportFormat format,
    required String extension,
    required String title,
    required String description,
    required IconData icon,
    required Color badgeColor,
  }) {
    final isSelected = _selectedFormat == format;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => setState(() => _selectedFormat = format),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E1E1E) : const Color(0xFF161616),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.samsungOrange : const Color(0xFF262626),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: badgeColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          extension,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppColors.amoledTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.samsungOrange : Colors.white30,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper functions to perform single note and backup zip exports with file opening & toasts
class NoteExportService {
  /// Exports a single note as either .txt or .pdf, saves it to Downloads/Documents,
  /// and prompts to open it.
  static Future<void> exportSingleNote(
    BuildContext context,
    NoteDocument doc, {
    required ExportFormat format,
  }) async {
    try {
      TopIslandToast.show(
        context,
        message: 'Generating ${format == ExportFormat.txt ? ".txt" : ".pdf"} file...',
        isLoading: true,
        color: AppColors.samsungOrange,
      );

      final Directory outDir = await getExportDirectory();
      String rawTitle = doc.metadata.title.trim();
      if (rawTitle.isEmpty) rawTitle = 'Untitled Note';
      final safeTitle = rawTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      final ext = format == ExportFormat.txt ? 'txt' : 'pdf';
      final fileName = '${safeTitle}_${DateTime.now().millisecondsSinceEpoch % 10000}.$ext';
      final file = File(p.join(outDir.path, fileName));

      if (format == ExportFormat.txt) {
        final text = TextExporter.exportToPlainText(doc);
        await file.writeAsString(text);
      } else {
        final pdfBytes = await PdfExporter.exportToPdf(doc);
        await file.writeAsBytes(pdfBytes);
      }

      if (context.mounted) {
        TopIslandToast.dismiss();
        TopIslandToast.show(
          context,
          message: 'Saved: $fileName',
          icon: Icons.check_circle_outline_rounded,
          color: AppColors.accentEmerald,
          duration: const Duration(seconds: 5),
          trailing: TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              openExportFolder(outDir.path, filePath: Platform.isWindows ? file.path : null);
            },
            child: const Text('View', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        TopIslandToast.dismiss();
        TopIslandToast.show(
          context,
          message: 'Export failed: $e',
          icon: Icons.error_outline_rounded,
          color: AppColors.accentRose,
        );
      }
    }
  }

  /// Exports an entire list of notes as a zip archive of either .txt or .pdf files.
  static Future<void> exportNotesBackupArchive(
    BuildContext context,
    List<NoteDocument> notes, {
    required ExportFormat format,
  }) async {
    if (notes.isEmpty) {
      TopIslandToast.show(
        context,
        message: 'No notes to export in backup archive.',
        icon: Icons.info_outline_rounded,
        color: AppColors.samsungOrange,
      );
      return;
    }

    final extType = format == ExportFormat.txt ? 'txt' : 'pdf';

    try {
      TopIslandToast.show(
        context,
        message: 'Creating backup ZIP with ${notes.length} ${extType.toUpperCase()} notes...',
        isLoading: true,
        color: AppColors.samsungOrange,
        duration: const Duration(seconds: 30),
      );

      final zipBytes = await NoteArchiveManager.createBackupZip(notes, format: extType);

      final Directory outDir = await getExportDirectory();
      final dateStr = DateTime.now().toIso8601String().split('T').first;
      final fileName = 'wznotes_backup_${extType}_$dateStr.zip';
      final file = File(p.join(outDir.path, fileName));
      await file.writeAsBytes(zipBytes);

      if (context.mounted) {
        TopIslandToast.dismiss();
        TopIslandToast.show(
          context,
          message: 'Backup saved: $fileName (${(zipBytes.length / 1024).toStringAsFixed(1)} KB)',
          icon: Icons.check_circle_outline_rounded,
          color: AppColors.accentEmerald,
          duration: const Duration(seconds: 6),
          trailing: TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              openExportFolder(outDir.path, filePath: Platform.isWindows ? file.path : null);
            },
            child: const Text('View', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        TopIslandToast.dismiss();
        TopIslandToast.show(
          context,
          message: 'Backup creation failed: $e',
          icon: Icons.error_outline_rounded,
          color: AppColors.accentRose,
        );
      }
    }
  }

  /// Opens the folder of the exported item across Android and Windows.
  /// Guarantees that on Android, the directory/file manager is opened,
  /// never prompting text viewer applications.
  static Future<void> openExportFolder(String folderPath, {String? filePath}) async {
    try {
      if (Platform.isAndroid) {
        const platform = MethodChannel('dev.opennotes.app/file_manager');
        final success = await platform.invokeMethod<bool>('openFolder', {'folderPath': folderPath});
        if (success == true) return;
        // Fallback on Android: open directory directly
        await OpenFilex.open(folderPath);
        return;
      } else if (Platform.isWindows) {
        if (filePath != null && File(filePath).existsSync()) {
          await Process.run('explorer.exe', ['/select,${filePath.replaceAll('/', '\\')}']);
          return;
        } else {
          await Process.run('explorer.exe', [folderPath.replaceAll('/', '\\')]);
          return;
        }
      }
    } catch (_) {}

    // Fallback: ALWAYS open the folderPath, NEVER open filePath as text document!
    try {
      await OpenFilex.open(folderPath);
    } catch (_) {}
  }

  /// Pre-creates and verifies the dedicated WZNotes folder where exported notes & backups reside.
  /// Called when the first note is created or upon app initialization.
  static Future<Directory?> ensureExportDirectoryCreated() async {
    try {
      return await getExportDirectory();
    } catch (_) {
      return null;
    }
  }

  /// Gets the dedicated WZNotes folder where exported notes & backups are stored.
  /// On Android: /storage/emulated/0/Documents/WZNotes (accessible directly in Files app)
  /// On Windows: C:\Users\<user>\Documents\WZNotes
  static Future<Directory> getExportDirectory() async {
    Directory targetDir;
    if (Platform.isAndroid) {
      // Primary standard public Documents directory
      final primaryDoc = Directory('/storage/emulated/0/Documents/WZNotes');
      try {
        if (!primaryDoc.existsSync()) {
          primaryDoc.createSync(recursive: true);
        }
        return primaryDoc;
      } catch (_) {
        // Fallback to Download/WZNotes or external storage
        final primaryDownload = Directory('/storage/emulated/0/Download/WZNotes');
        try {
          if (!primaryDownload.existsSync()) {
            primaryDownload.createSync(recursive: true);
          }
          return primaryDownload;
        } catch (_) {
          final ext = await getExternalStorageDirectory();
          targetDir = Directory(p.join(ext?.path ?? (await getApplicationDocumentsDirectory()).path, 'WZNotes'));
        }
      }
    } else {
      try {
        final docDir = await getApplicationDocumentsDirectory();
        targetDir = Directory(p.join(docDir.path, 'WZNotes'));
      } catch (_) {
        targetDir = Directory(p.join(Directory.systemTemp.path, 'WZNotes'));
      }
    }

    try {
      if (!targetDir.existsSync()) {
        targetDir.createSync(recursive: true);
      }
    } catch (_) {}
    return targetDir;
  }
}
