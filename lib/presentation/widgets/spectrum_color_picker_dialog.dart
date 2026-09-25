import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Modern AMOLED Spectrum Color Picker Dialog with smooth pop-in and pop-out
class SpectrumColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorConfirmed;

  const SpectrumColorPickerDialog({
    super.key,
    required this.initialColor,
    required this.onColorConfirmed,
  });

  /// Displays the spectrum picker dialog with a sleek pop-in / pop-out animation
  static Future<Color?> show(
    BuildContext context, {
    required Color initialColor,
    required ValueChanged<Color> onColorConfirmed,
  }) {
    return showGeneralDialog<Color>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Color Spectrum',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim1, anim2) => SpectrumColorPickerDialog(
        initialColor: initialColor,
        onColorConfirmed: onColorConfirmed,
      ),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<SpectrumColorPickerDialog> createState() => _SpectrumColorPickerDialogState();
}

class _SpectrumColorPickerDialogState extends State<SpectrumColorPickerDialog> {
  late HSVColor _hsvColor;

  // Preset quick picks
  static const List<Color> _quickPicks = [
    Color(0xFFFFFFFF), // White
    Color(0xFFFF6D00), // Samsung Orange
    Color(0xFFFF1744), // Crimson
    Color(0xFFFF4081), // Pink
    Color(0xFFAA00FF), // Violet
    Color(0xFF2979FF), // Electric Blue
    Color(0xFF00E5FF), // Cyan
    Color(0xFF00E676), // Spring Green
    Color(0xFFFFEA00), // Yellow
    Color(0xFFFF9100), // Amber
    Color(0xFF8D6E63), // Brown
    Color(0xFF9E9E9E), // Silver
  ];

  @override
  void initState() {
    super.initState();
    _hsvColor = HSVColor.fromColor(widget.initialColor);
  }

  Color get _currentColor => _hsvColor.toColor();

  String get _hexCode {
    final c = _currentColor;
    return '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  void _confirm() {
    widget.onColorConfirmed(_currentColor);
    Navigator.of(context).pop(_currentColor);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 360,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFF2C2C2C), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Colors.red,
                          Colors.orange,
                          Colors.yellow,
                          Colors.green,
                          Colors.cyan,
                          Colors.blue,
                          Colors.purple,
                          Colors.red,
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.palette_rounded, color: Colors.white, size: 17),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Color Spectrum',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Choose any custom shade or hue',
                          style: TextStyle(
                            color: AppColors.amoledTextSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // 2D Saturation / Value Spectrum Plane
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 160,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        onPanDown: (details) => _updateSatVal(details.localPosition, constraints),
                        onPanUpdate: (details) => _updateSatVal(details.localPosition, constraints),
                        child: CustomPaint(
                          size: Size(constraints.maxWidth, 160),
                          painter: _SatValSpectrumPainter(
                            hue: _hsvColor.hue,
                            saturation: _hsvColor.saturation,
                            value: _hsvColor.value,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Hue Gradient Bar (0° to 360°)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 26,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        onPanDown: (details) => _updateHue(details.localPosition, constraints),
                        onPanUpdate: (details) => _updateHue(details.localPosition, constraints),
                        child: CustomPaint(
                          size: Size(constraints.maxWidth, 26),
                          painter: _HueBarPainter(hue: _hsvColor.hue),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Color Preview + Hex code
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _currentColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white54, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: _currentColor.withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _hexCode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'H:${_hsvColor.hue.toInt()}° S:${(_hsvColor.saturation * 100).toInt()}% V:${(_hsvColor.value * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Quick Pick Palette Swatches
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _quickPicks.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 7),
                  itemBuilder: (context, i) {
                    final c = _quickPicks[i];
                    final isSel = (_currentColor.toARGB32() & 0x00FFFFFF) == (c.toARGB32() & 0x00FFFFFF);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _hsvColor = HSVColor.fromColor(c);
                        });
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSel ? Theme.of(context).colorScheme.primary : Colors.white24,
                            width: isSel ? 2.5 : 1.0,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Confirm Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: _confirm,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_rounded, size: 20, color: Colors.black),
                    SizedBox(width: 8),
                    Text(
                      'Confirm Color',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateSatVal(Offset localPos, BoxConstraints constraints) {
    final double sat = (localPos.dx / constraints.maxWidth).clamp(0.0, 1.0);
    final double val = (1.0 - (localPos.dy / 160.0)).clamp(0.0, 1.0);
    setState(() {
      _hsvColor = _hsvColor.withSaturation(sat).withValue(val);
    });
  }

  void _updateHue(Offset localPos, BoxConstraints constraints) {
    final double pct = (localPos.dx / constraints.maxWidth).clamp(0.0, 1.0);
    final double hue = (pct * 360.0).clamp(0.0, 360.0);
    setState(() {
      _hsvColor = _hsvColor.withHue(hue == 360.0 ? 0.0 : hue);
    });
  }
}

/// 2D Saturation / Value Spectrum Plane Painter
class _SatValSpectrumPainter extends CustomPainter {
  final double hue;
  final double saturation;
  final double value;

  _SatValSpectrumPainter({
    required this.hue,
    required this.saturation,
    required this.value,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Base pure hue color
    final pureHue = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();

    // 1. Horizontal gradient: white to pure hue
    final horizontalShader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Colors.white, pureHue],
    ).createShader(rect);

    final paintH = Paint()..shader = horizontalShader;
    canvas.drawRect(rect, paintH);

    // 2. Vertical gradient: transparent to black
    final verticalShader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, Colors.black],
    ).createShader(rect);

    final paintV = Paint()..shader = verticalShader;
    canvas.drawRect(rect, paintV);

    // Selection thumb marker
    final thumbX = saturation * size.width;
    final thumbY = (1.0 - value) * size.height;
    final thumbCenter = Offset(thumbX, thumbY);

    final currentDisplayColor = HSVColor.fromAHSV(1.0, hue, saturation, value).toColor();

    // Ring shadow
    canvas.drawCircle(thumbCenter, 9, Paint()..color = Colors.black45);
    // Outer white ring
    canvas.drawCircle(
      thumbCenter,
      8,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    // Inner color circle
    canvas.drawCircle(
      thumbCenter,
      5.5,
      Paint()..color = currentDisplayColor,
    );
  }

  @override
  bool shouldRepaint(covariant _SatValSpectrumPainter oldDelegate) {
    return oldDelegate.hue != hue ||
        oldDelegate.saturation != saturation ||
        oldDelegate.value != value;
  }
}

/// Rainbow Hue Slider Bar Painter
class _HueBarPainter extends CustomPainter {
  final double hue;

  _HueBarPainter({required this.hue});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    const rainbowColors = [
      Color(0xFFFF0000),
      Color(0xFFFFFF00),
      Color(0xFF00FF00),
      Color(0xFF00FFFF),
      Color(0xFF0000FF),
      Color(0xFFFF00FF),
      Color(0xFFFF0000),
    ];

    final shader = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: rainbowColors,
    ).createShader(rect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      Paint()..shader = shader,
    );

    // Thumb indicator
    final double thumbX = (hue / 360.0).clamp(0.0, 1.0) * size.width;
    final thumbRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(thumbX, size.height / 2), width: 14, height: size.height + 4),
      const Radius.circular(6),
    );

    canvas.drawRRect(
      thumbRect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _HueBarPainter oldDelegate) {
    return oldDelegate.hue != hue;
  }
}
