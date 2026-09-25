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
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.file_download_outlined, color: Theme.of(context).colorScheme.primary, size: 24),
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
                        backgroundColor: Theme.of(context).colorScheme.primary,
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
            color: isSelected ? Theme.of(context).colorScheme.primary : const Color(0xFF262626),
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
              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white30,
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
        color: Theme.of(context).colorScheme.primary,
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
          duration: const Duration(seconds: 6),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  openExportFile(file.path);
                },
                child: const Text('View', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(width: 4),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  openExportFolder(outDir.path, filePath: file.path);
                },
                child: const Text('Folder', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
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
        color: Theme.of(context).colorScheme.primary,
      );
      return;
    }

    final extType = format == ExportFormat.txt ? 'txt' : 'pdf';

    try {
      TopIslandToast.show(
        context,
        message: 'Creating backup ZIP with ${notes.length} ${extType.toUpperCase()} notes...',
        isLoading: true,
        color: Theme.of(context).colorScheme.primary,
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
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  openExportFile(file.path);
                },
                child: const Text('View', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(width: 4),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  openExportFolder(outDir.path, filePath: file.path);
                },
                child: const Text('Folder', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
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

  /// Opens the exported file (.txt, .pdf, .zip) directly using default system viewer.
  static Future<void> openExportFile(String filePath) async {
    try {
      if (File(filePath).existsSync()) {
        await OpenFilex.open(filePath);
      }
    } catch (_) {}
  }

  /// Opens the folder containing the exported file across Android, Windows, and macOS/Linux.
  /// On Windows: Launches Explorer with the file selected via /select switch.
  /// On Android: Uses targeted MethodChannel to open the file manager to the folder.
  /// NEVER passes directory paths to OpenFilex (which causes EISDIR in text editors).
  static Future<void> openExportFolder(String folderPath, {String? filePath}) async {
    try {
      if (Platform.isAndroid) {
        const platform = MethodChannel('dev.opennotes.app/file_manager');
        final success = await platform.invokeMethod<bool>('openFolder', {
          'folderPath': folderPath,
          'filePath': filePath,
        });
        if (success == true) return;

        // If file manager couldn't be launched directly, open the file itself
        if (filePath != null && File(filePath).existsSync()) {
          await OpenFilex.open(filePath);
        }
        return;
      } else if (Platform.isWindows) {
        if (filePath != null && File(filePath).existsSync()) {
          final winFilePath = filePath.replaceAll('/', '\\');
          await Process.run('explorer.exe', ['/select,$winFilePath']);
          return;
        } else {
          final winFolderPath = folderPath.replaceAll('/', '\\');
          await Process.run('explorer.exe', [winFolderPath]);
          return;
        }
      } else if (Platform.isMacOS) {
        if (filePath != null && File(filePath).existsSync()) {
          await Process.run('open', ['-R', filePath]);
          return;
        } else {
          await Process.run('open', [folderPath]);
          return;
        }
      } else if (Platform.isLinux) {
        if (filePath != null && File(filePath).existsSync()) {
          await Process.run('xdg-open', [folderPath]);
          return;
        } else {
          await Process.run('xdg-open', [folderPath]);
          return;
        }
      }
    } catch (_) {}

    // Fallback: If opening folder fails, open the file if available. NEVER open folder with OpenFilex!
    if (filePath != null && File(filePath).existsSync()) {
      try {
        await OpenFilex.open(filePath);
      } catch (_) {}
    }
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

  static bool _testDirectoryWritable(Directory dir) {
    try {
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final testFile = File(p.join(dir.path, '.test_write_${DateTime.now().millisecondsSinceEpoch}'));
      testFile.writeAsStringSync('ok');
      testFile.deleteSync();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Gets the dedicated WZNotes folder where exported notes & backups are stored.
  /// On Android: Tests public Documents/WZNotes, Download/WZNotes, and falls back to
  /// external app storage if scoped storage restricts direct POSIX writes.
  /// On Windows: C:\Users\<user>\Documents\WZNotes
  static Future<Directory> getExportDirectory() async {
    Directory targetDir;
    if (Platform.isAndroid) {
      // 1. Primary standard public Documents directory
      final primaryDoc = Directory('/storage/emulated/0/Documents/WZNotes');
      if (_testDirectoryWritable(primaryDoc)) {
        return primaryDoc;
      }

      // 2. Fallback to public Download directory
      final primaryDownload = Directory('/storage/emulated/0/Download/WZNotes');
      if (_testDirectoryWritable(primaryDownload)) {
        return primaryDownload;
      }

      // 3. Fallback to app external storage (always accessible on Android)
      try {
        final ext = await getExternalStorageDirectory();
        if (ext != null) {
          final extTarget = Directory(p.join(ext.path, 'WZNotes'));
          if (_testDirectoryWritable(extTarget)) {
            return extTarget;
          }
        }
      } catch (_) {}

      // 4. Fallback to application documents
      final appDocs = await getApplicationDocumentsDirectory();
      targetDir = Directory(p.join(appDocs.path, 'WZNotes'));
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
