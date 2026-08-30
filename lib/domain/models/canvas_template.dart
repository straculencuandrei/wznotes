import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/canvas_dimensions.dart';

enum CanvasTemplateType {
  blank,
  lined,
  grid,
  dotted,
  pdf,
}

/// Canvas background styling and layout configuration
class CanvasTemplate {
  final CanvasTemplateType type;
  final double lineSpacing;
  final Color lineColor;
  final Color backgroundColor;
  final String? pdfAssetPath;

  const CanvasTemplate({
    this.type = CanvasTemplateType.blank,
    this.lineSpacing = CanvasDimensions.defaultRuledLineSpacing,
    this.lineColor = AppColors.amoledBorder,
    this.backgroundColor = AppColors.amoledBlack,
    this.pdfAssetPath,
  });

  CanvasTemplate copyWith({
    CanvasTemplateType? type,
    double? lineSpacing,
    Color? lineColor,
    Color? backgroundColor,
    String? pdfAssetPath,
  }) {
    return CanvasTemplate(
      type: type ?? this.type,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      lineColor: lineColor ?? this.lineColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      pdfAssetPath: pdfAssetPath ?? this.pdfAssetPath,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'lineSpacing': lineSpacing,
        'lineColor': '#${lineColor.value.toRadixString(16).padLeft(8, '0')}',
        'backgroundColor': '#${backgroundColor.value.toRadixString(16).padLeft(8, '0')}',
        if (pdfAssetPath != null) 'pdfAssetPath': pdfAssetPath,
      };

  factory CanvasTemplate.fromJson(Map<String, dynamic> json) {
    return CanvasTemplate(
      type: CanvasTemplateType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => CanvasTemplateType.blank,
      ),
      lineSpacing: (json['lineSpacing'] as num?)?.toDouble() ?? CanvasDimensions.defaultRuledLineSpacing,
      lineColor: json['lineColor'] != null
          ? Color(int.parse((json['lineColor'] as String).replaceAll('#', ''), radix: 16))
          : AppColors.amoledBorder,
      backgroundColor: json['backgroundColor'] != null
          ? Color(int.parse((json['backgroundColor'] as String).replaceAll('#', ''), radix: 16))
          : AppColors.amoledBlack,
      pdfAssetPath: json['pdfAssetPath'] as String?,
    );
  }
}
