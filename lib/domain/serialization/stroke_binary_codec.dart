import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/stroke_point.dart';
import '../models/vector_stroke.dart';
import '../models/pen_tool.dart';

/// High-efficiency packed binary serializer for vector strokes (`strokes.bin`)
///
/// Format Specification:
/// - Magic Header (4 bytes): 'OPNT' (0x4F, 0x50, 0x4E, 0x54)
/// - Version (2 bytes uint16): 1
/// - Stroke Count (4 bytes uint32)
/// - Per-Stroke Record:
///   - ID length (uint8) + ID UTF8 bytes
///   - toolType (uint8)
///   - color ARGB (uint32)
///   - baseWidth (float32)
///   - opacity (float32)
///   - blendMode index (uint8)
///   - audioTimecodeMs (int32)
///   - isShapeSnapped (uint8)
///   - pointCount (uint32)
///   - Array of Points (each point = 16 bytes):
///     - x (float32)
///     - y (float32)
///     - pressure (uint16 mapped from 0.0..1.0 to 0..65535)
///     - timestampDeltaMs (uint16)
///     - tilt (int8 mapped from -90..90 deg)
///     - orientation (int8 mapped from 0..360 deg)
///     - reserved (uint16)
class StrokeBinaryCodec {
  static const List<int> magicHeader = [0x4F, 0x50, 0x4E, 0x54]; // 'OPNT'
  static const int currentVersion = 1;

  /// Encodes a list of VectorStrokes into a packed binary byte buffer
  static Uint8List encode(List<VectorStroke> strokes) {
    final builder = BytesBuilder();

    // 1. Write Header
    builder.add(magicHeader);

    // Version (uint16)
    final versionBytes = ByteData(2)..setUint16(0, currentVersion, Endian.little);
    builder.add(versionBytes.buffer.asUint8List());

    // Stroke Count (uint32)
    final countBytes = ByteData(4)..setUint32(0, strokes.length, Endian.little);
    builder.add(countBytes.buffer.asUint8List());

    // 2. Write Each Stroke
    for (final stroke in strokes) {
      final idBytes = Uint8List.fromList(stroke.id.codeUnits);
      builder.addByte(idBytes.length);
      builder.add(idBytes);

      final strokeMeta = ByteData(19);
      strokeMeta.setUint8(0, stroke.toolType.index);
      strokeMeta.setUint32(1, stroke.color.value, Endian.little);
      strokeMeta.setFloat32(5, stroke.baseWidth, Endian.little);
      strokeMeta.setFloat32(9, stroke.opacity, Endian.little);
      strokeMeta.setUint8(13, stroke.blendMode.index);
      strokeMeta.setInt32(14, stroke.audioTimecodeMs, Endian.little);
      strokeMeta.setUint8(18, stroke.isShapeSnapped ? 1 : 0);
      builder.add(strokeMeta.buffer.asUint8List());

      // Point count
      final ptCountData = ByteData(4)..setUint32(0, stroke.points.length, Endian.little);
      builder.add(ptCountData.buffer.asUint8List());

      // Write Points
      final baseTime = stroke.points.isNotEmpty ? stroke.points.first.timestampMs : 0;
      final pointsBuffer = ByteData(stroke.points.length * 16);

      for (int i = 0; i < stroke.points.length; i++) {
        final p = stroke.points[i];
        final offset = i * 16;
        pointsBuffer.setFloat32(offset + 0, p.x, Endian.little);
        pointsBuffer.setFloat32(offset + 4, p.y, Endian.little);

        final int uPressure = (p.pressure.clamp(0.0, 1.0) * 65535).round();
        pointsBuffer.setUint16(offset + 8, uPressure, Endian.little);

        final int dt = (p.timestampMs - baseTime).clamp(0, 65535);
        pointsBuffer.setUint16(offset + 10, dt, Endian.little);

        final int sTilt = (p.tilt * 57.2958).round().clamp(-128, 127); // rad to deg
        pointsBuffer.setInt8(offset + 12, sTilt);

        final int sOr = (p.orientation * 57.2958 / 2.0).round().clamp(0, 255);
        pointsBuffer.setUint8(offset + 13, sOr);

        pointsBuffer.setUint16(offset + 14, 0, Endian.little); // reserved
      }
      builder.add(pointsBuffer.buffer.asUint8List());
    }

    return builder.toBytes();
  }

  /// Decodes a packed binary buffer into a list of VectorStrokes
  static List<VectorStroke> decode(Uint8List bytes) {
    if (bytes.length < 10) return [];

    // Verify magic header
    if (bytes[0] != 0x4F || bytes[1] != 0x50 || bytes[2] != 0x4E || bytes[3] != 0x54) {
      throw const FormatException('Invalid OPNT magic header in strokes.bin');
    }

    final byteData = ByteData.sublistView(bytes);
    int offset = 4;

    final int version = byteData.getUint16(offset, Endian.little);
    offset += 2;
    if (version != 1) {
      throw FormatException('Unsupported strokes.bin version: $version');
    }

    final int strokeCount = byteData.getUint32(offset, Endian.little);
    offset += 4;

    final List<VectorStroke> strokes = [];

    for (int s = 0; s < strokeCount; s++) {
      if (offset >= bytes.length) break;

      final int idLen = byteData.getUint8(offset);
      offset += 1;

      final id = String.fromCharCodes(bytes.sublist(offset, offset + idLen));
      offset += idLen;

      final int toolTypeIdx = byteData.getUint8(offset);
      final int colorValue = byteData.getUint32(offset + 1, Endian.little);
      final double baseWidth = byteData.getFloat32(offset + 5, Endian.little);
      final double opacity = byteData.getFloat32(offset + 9, Endian.little);
      final int blendModeIdx = byteData.getUint8(offset + 13);
      final int audioTimecodeMs = byteData.getInt32(offset + 14, Endian.little);
      final bool isShapeSnapped = byteData.getUint8(offset + 18) == 1;
      offset += 19;

      final int pointCount = byteData.getUint32(offset, Endian.little);
      offset += 4;

      final List<StrokePoint> points = [];
      final int baseTimestamp = audioTimecodeMs > 0 ? audioTimecodeMs : 0;

      for (int p = 0; p < pointCount; p++) {
        final double x = byteData.getFloat32(offset + 0, Endian.little);
        final double y = byteData.getFloat32(offset + 4, Endian.little);
        final double pressure = byteData.getUint16(offset + 8, Endian.little) / 65535.0;
        final int dt = byteData.getUint16(offset + 10, Endian.little);
        final double tilt = byteData.getInt8(offset + 12) / 57.2958;
        final double orientation = (byteData.getUint8(offset + 13) * 2.0) / 57.2958;
        offset += 16;

        points.add(StrokePoint(
          x: x,
          y: y,
          pressure: pressure,
          timestampMs: baseTimestamp + dt,
          tilt: tilt,
          orientation: orientation,
        ));
      }

      strokes.add(VectorStroke(
        id: id,
        toolType: toolTypeIdx < PenType.values.length ? PenType.values[toolTypeIdx] : PenType.ballpoint,
        color: Color(colorValue),
        baseWidth: baseWidth,
        opacity: opacity,
        blendMode: blendModeIdx < BlendMode.values.length ? BlendMode.values[blendModeIdx] : BlendMode.srcOver,
        audioTimecodeMs: audioTimecodeMs,
        isShapeSnapped: isShapeSnapped,
        points: points,
      ));
    }

    return strokes;
  }
}
