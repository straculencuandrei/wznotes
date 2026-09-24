import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/constants/app_colors.dart';

class QrScannerScreen extends StatefulWidget {
  final Map<String, String>? Function(String raw) parser;

  const QrScannerScreen({
    super.key,
    required this.parser,
  });

  static Future<Map<String, String>?> scan(
    BuildContext context, {
    required Map<String, String>? Function(String raw) parser,
  }) {
    if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera scanning is only available on mobile devices.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return Future.value(null);
    }

    return Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(
        builder: (_) => QrScannerScreen(parser: parser),
      ),
    );
  }

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _animationController;
  late final Animation<double> _scanLineAnimation;
  bool _hasScanned = false;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      returnImage: false,
    );

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        final parsed = widget.parser(raw);
        if (parsed != null && parsed['ip'] != null && parsed['ip']!.isNotEmpty) {
          _hasScanned = true;
          HapticFeedback.heavyImpact();
          Navigator.of(context).pop(parsed);
          return;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanSize = MediaQuery.of(context).size.width * 0.72;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera Viewfinder
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),
          ),

          // 2. Dark Mask Overlay with Cutout
          Positioned.fill(
            child: _ScannerOverlayMask(
              scanBoxSize: scanSize,
            ),
          ),

          // 3. Animated Orange Laser Scan Line & Corner Borders
          Center(
            child: SizedBox(
              width: scanSize,
              height: scanSize,
              child: Stack(
                children: [
                  // Corner markers
                  const _ScanCornerMarkers(color: AppColors.samsungOrange),

                  // Animated laser line
                  AnimatedBuilder(
                    animation: _scanLineAnimation,
                    builder: (context, child) {
                      return Positioned(
                        top: _scanLineAnimation.value * (scanSize - 4),
                        left: 8,
                        right: 8,
                        child: Container(
                          height: 2.5,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.samsungOrange.withValues(alpha: 0.1),
                                AppColors.samsungOrange,
                                AppColors.samsungOrange.withValues(alpha: 0.1),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.samsungOrange.withValues(alpha: 0.7),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // 4. Header Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Scan PC QR Code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Flashlight toggle
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: _isTorchOn ? AppColors.samsungOrange : Colors.white,
                  ),
                  icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off, size: 20),
                  onPressed: () async {
                    try {
                      await _controller.toggleTorch();
                      if (mounted) {
                        setState(() {
                          _isTorchOn = !_isTorchOn;
                        });
                      }
                    } catch (_) {}
                  },
                ),
                const SizedBox(width: 8),
                // Camera switcher
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.flip_camera_ios, size: 20),
                  onPressed: () => _controller.switchCamera(),
                ),
              ],
            ),
          ),

          // 5. Instruction Footer
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 36,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.desktop_windows_rounded, size: 18, color: AppColors.samsungOrange),
                      SizedBox(width: 8),
                      Text(
                        'Align with PC Screen QR Code',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Position the QR code shown in WZNotes on your PC inside the frame. Details and PIN will auto-fill instantly.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.amoledTextSecondary,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlayMask extends StatelessWidget {
  final double scanBoxSize;

  const _ScannerOverlayMask({required this.scanBoxSize});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OverlayPainter(scanBoxSize: scanBoxSize),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final double scanBoxSize;

  _OverlayPainter({required this.scanBoxSize});

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(center: center, width: scanBoxSize, height: scanBoxSize);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(20));

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, backgroundPaint);
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) =>
      oldDelegate.scanBoxSize != scanBoxSize;
}

class _ScanCornerMarkers extends StatelessWidget {
  final Color color;

  const _ScanCornerMarkers({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _CornerPainter(color: color),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;

  _CornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 28.0;
    const cornerRadius = 16.0;

    // Top-Left
    canvas.drawPath(
      Path()
        ..moveTo(0, cornerLength)
        ..lineTo(0, cornerRadius)
        ..arcToPoint(const Offset(cornerRadius, 0), radius: const Radius.circular(cornerRadius))
        ..lineTo(cornerLength, 0),
      paint,
    );

    // Top-Right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerLength, 0)
        ..lineTo(size.width - cornerRadius, 0)
        ..arcToPoint(Offset(size.width, cornerRadius), radius: const Radius.circular(cornerRadius))
        ..lineTo(size.width, cornerLength),
      paint,
    );

    // Bottom-Left
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - cornerLength)
        ..lineTo(0, size.height - cornerRadius)
        ..arcToPoint(Offset(cornerRadius, size.height), radius: const Radius.circular(cornerRadius))
        ..lineTo(cornerLength, size.height),
      paint,
    );

    // Bottom-Right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerLength, size.height)
        ..lineTo(size.width - cornerRadius, size.height)
        ..arcToPoint(Offset(size.width, size.height - cornerRadius), radius: const Radius.circular(cornerRadius))
        ..lineTo(size.width, size.height - cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CornerPainter oldDelegate) => oldDelegate.color != color;
}
