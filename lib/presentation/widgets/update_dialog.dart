import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../infrastructure/update/models/app_update_info.dart';

class UpdateDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;
  final VoidCallback? onDismiss;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
    this.onDismiss,
  });

  static Future<void> show(
    BuildContext context, {
    required AppUpdateInfo updateInfo,
    VoidCallback? onDismiss,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: !updateInfo.isMandatory,
      builder: (ctx) => UpdateDialog(updateInfo: updateInfo, onDismiss: onDismiss),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatusText = '';
  String? _downloadedFilePath;
  String? _errorMessage;

  String get _targetUrl {
    if (Platform.isAndroid && widget.updateInfo.androidUrl.isNotEmpty) {
      return widget.updateInfo.androidUrl;
    } else if (Platform.isWindows && widget.updateInfo.windowsUrl.isNotEmpty) {
      return widget.updateInfo.windowsUrl;
    }
    return widget.updateInfo.androidUrl.isNotEmpty
        ? widget.updateInfo.androidUrl
        : widget.updateInfo.windowsUrl;
  }

  Future<void> _startInAppDownloadAndInstall() async {
    final url = _targetUrl;
    if (url.isEmpty) {
      setState(() => _errorMessage = 'No download link found for this platform.');
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadStatusText = 'Starting download...';
      _errorMessage = null;
    });

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Server returned HTTP ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;

      final tempDir = Platform.isAndroid
          ? await getExternalStorageDirectory() ?? await getTemporaryDirectory()
          : await getTemporaryDirectory();

      final extension = Platform.isAndroid ? '.apk' : (url.endsWith('.zip') ? '.zip' : '.exe');
      final fileName = 'wznotes-v${widget.updateInfo.version}$extension';
      final file = File(p.join(tempDir.path, fileName));
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;

        if (mounted) {
          setState(() {
            if (totalBytes > 0) {
              _downloadProgress = receivedBytes / totalBytes;
              final recMB = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
              final totalMB = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
              final pct = (_downloadProgress * 100).toInt();
              _downloadStatusText = 'Downloading: $recMB / $totalMB MB ($pct%)';
            } else {
              final recMB = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
              _downloadStatusText = 'Downloaded: $recMB MB';
            }
          });
        }
      }

      await sink.flush();
      await sink.close();
      client.close();

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 1.0;
          _downloadedFilePath = file.path;
          _downloadStatusText = 'Download complete! Launching installer...';
        });
      }

      // Automatically launch Package Installer on Android or open file on Windows
      await _installDownloadedFile(file.path);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Download failed: $e';
        });
      }
    }
  }

  Future<void> _installDownloadedFile(String filePath) async {
    try {
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done && mounted) {
        // Fallback: try open in browser
        _launchBrowserFallback();
      }
    } catch (_) {
      _launchBrowserFallback();
    }
  }

  Future<void> _launchBrowserFallback() async {
    final uri = Uri.parse(_targetUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWin = Platform.isWindows;
    final isAndroid = Platform.isAndroid;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.amoledSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.samsungOrange.withValues(alpha: 0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.samsungOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.system_update_rounded, color: AppColors.samsungOrange, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.updateInfo.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.samsungOrange,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'v${widget.updateInfo.version} (${widget.updateInfo.buildNumber})',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Release Notes Box
            if (widget.updateInfo.releaseNotes.isNotEmpty && !_isDownloading) ...[
              const Text(
                'WHAT\'S NEW',
                style: TextStyle(
                  color: AppColors.samsungOrange,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 160),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.amoledBlack,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.amoledBorder),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    widget.updateInfo.releaseNotes,
                    style: const TextStyle(
                      color: AppColors.amoledTextPrimary,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Download Progress Bar UI
            if (_isDownloading || _downloadedFilePath != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.amoledBlack,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.samsungOrange.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (_isDownloading)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.samsungOrange),
                          )
                        else
                          const Icon(Icons.check_circle_rounded, color: AppColors.accentEmerald, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _downloadStatusText,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: _downloadProgress > 0 ? _downloadProgress : null,
                      backgroundColor: AppColors.amoledBorder,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.samsungOrange),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Error Message UI
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Action Buttons
            Row(
              children: [
                if (!widget.updateInfo.isMandatory && !_isDownloading) ...[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.amoledTextSecondary,
                        side: const BorderSide(color: AppColors.amoledBorder),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        widget.onDismiss?.call();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Later', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.samsungOrange,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isDownloading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : Icon(_downloadedFilePath != null ? Icons.install_mobile_rounded : Icons.download_rounded, size: 20),
                    label: Text(
                      _downloadedFilePath != null
                          ? (isAndroid ? 'Install APK' : 'Open Installer')
                          : (_isDownloading
                              ? 'Downloading...'
                              : (isAndroid ? 'Download & Install APK' : (isWin ? 'Download PC Update' : 'Download Update'))),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    onPressed: _isDownloading
                        ? null
                        : (_downloadedFilePath != null
                            ? () => _installDownloadedFile(_downloadedFilePath!)
                            : () => _startInAppDownloadAndInstall()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
