import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/models/text_span_node.dart';
import '../../core/diagnostics/performance_benchmark.dart';

class FormattingSpan {
  int start;
  int end;
  bool isBold;
  bool isItalic;
  bool isStrike;

  FormattingSpan({
    required this.start,
    required this.end,
    this.isBold = false,
    this.isItalic = false,
    this.isStrike = false,
  });

  bool get isEmpty => start >= end || (!isBold && !isItalic && !isStrike);

  bool hasSameStyle(FormattingSpan other) {
    return isBold == other.isBold && isItalic == other.isItalic && isStrike == other.isStrike;
  }

  Map<String, dynamic> toJson() => {
        'start': start,
        'end': end,
        'isBold': isBold,
        'isItalic': isItalic,
        'isStrike': isStrike,
      };

  factory FormattingSpan.fromJson(Map<String, dynamic> json) => FormattingSpan(
        start: json['start'] as int? ?? 0,
        end: json['end'] as int? ?? 0,
        isBold: json['isBold'] as bool? ?? false,
        isItalic: json['isItalic'] as bool? ?? false,
        isStrike: json['isStrike'] as bool? ?? false,
      );
}

/// Pure WYSIWYG Span-Based Controller
/// Stores 100% clean plain text with zero markdown asterisks/tildes, persisting styles directly via spans
class RichSpanEditingController extends TextEditingController {
  TextStyle baseStyle;
  final List<FormattingSpan> _spans = [];

  bool activeBold = false;
  bool activeItalic = false;
  bool activeStrike = false;

  String _lastText = '';

  RichSpanEditingController({
    String? initialText,
    List<FormattingSpan>? initialSpans,
    required this.baseStyle,
  }) : super(text: _sanitizeLegacyMarkdown(initialText ?? '').cleanText) {
    final sanitized = _sanitizeLegacyMarkdown(initialText ?? '');
    _lastText = sanitized.cleanText;

    if (initialSpans != null && initialSpans.isNotEmpty) {
      _spans.addAll(initialSpans);
    } else {
      _spans.addAll(sanitized.spans);
    }

    _normalizeSpans(_lastText.length);
  }

  /// Cleans any legacy markdown syntax (**word**, ~~strike~~, *italic*) from older notes into pure plain text + spans
  static ({String cleanText, List<FormattingSpan> spans}) _sanitizeLegacyMarkdown(String raw) {
    if (raw.isEmpty) return (cleanText: '', spans: <FormattingSpan>[]);

    final regex = RegExp(r'(\*\*(.*?)\*\*|~~(.*?)~~|\*([^*]+)\*)');
    final buffer = StringBuffer();
    final List<FormattingSpan> spans = [];
    int lastIndex = 0;

    for (final match in regex.allMatches(raw)) {
      if (match.start > lastIndex) {
        buffer.write(raw.substring(lastIndex, match.start));
      }

      final full = match.group(0)!;
      final startPos = buffer.length;

      if (full.startsWith('**') && full.endsWith('**') && full.length >= 4) {
        final content = match.group(2) ?? '';
        buffer.write(content);
        final endPos = buffer.length;
        if (endPos > startPos) {
          spans.add(FormattingSpan(start: startPos, end: endPos, isBold: true));
        }
      } else if (full.startsWith('~~') && full.endsWith('~~') && full.length >= 4) {
        final content = match.group(3) ?? '';
        buffer.write(content);
        final endPos = buffer.length;
        if (endPos > startPos) {
          spans.add(FormattingSpan(start: startPos, end: endPos, isStrike: true));
        }
      } else if (full.startsWith('*') && full.endsWith('*') && full.length >= 2) {
        final content = match.group(4) ?? '';
        buffer.write(content);
        final endPos = buffer.length;
        if (endPos > startPos) {
          spans.add(FormattingSpan(start: startPos, end: endPos, isItalic: true));
        }
      }

      lastIndex = match.end;
    }

    if (lastIndex < raw.length) {
      buffer.write(raw.substring(lastIndex));
    }

    // Clean any stray asterisks or tildes from corrupt previous saves
    var clean = buffer.toString();
    clean = clean.replaceAll('**', '').replaceAll('~~', '');

    return (cleanText: clean, spans: spans);
  }

  List<FormattingSpan> get spans => List.unmodifiable(_spans);

  @override
  set value(TextEditingValue newValue) {
    _handleDeterministicDiff(_lastText, newValue.text);
    _lastText = newValue.text;
    super.value = newValue;
  }

  void _handleDeterministicDiff(String oldText, String newText) {
    if (oldText == newText) return;
    if (_spans.isEmpty && !activeBold && !activeItalic && !activeStrike) {
      return;
    }

    final oldLen = oldText.length;
    final newLen = newText.length;

    int prefix = 0;
    while (prefix < oldLen && prefix < newLen && oldText.codeUnitAt(prefix) == newText.codeUnitAt(prefix)) {
      prefix++;
    }

    int suffix = 0;
    while (suffix < (oldLen - prefix) && suffix < (newLen - prefix) &&
           oldText.codeUnitAt(oldLen - 1 - suffix) == newText.codeUnitAt(newLen - 1 - suffix)) {
      suffix++;
    }


    final int deletedCount = oldLen - prefix - suffix;
    final int insertedCount = newLen - prefix - suffix;
    final int deleteStart = prefix;
    final int deleteEnd = prefix + deletedCount;
    final int insertEnd = prefix + insertedCount;

    final List<FormattingSpan> updated = [];
    for (final span in _spans) {
      if (span.end <= deleteStart) {
        updated.add(span);
      } else if (span.start >= deleteEnd) {
        final delta = insertedCount - deletedCount;
        span.start += delta;
        span.end += delta;
        updated.add(span);
      } else {
        final newSpanStart = math.min(span.start, deleteStart);
        final newSpanEnd = span.end > deleteEnd ? span.end - deletedCount + insertedCount : deleteStart;
        if (newSpanEnd > newSpanStart) {
          span.start = newSpanStart;
          span.end = newSpanEnd;
          updated.add(span);
        }
      }
    }

    _spans.clear();
    _spans.addAll(updated);

    if ((activeBold || activeItalic || activeStrike) && insertedCount > 0 && insertedCount <= 3) {
      _spans.add(FormattingSpan(
        start: prefix,
        end: insertEnd,
        isBold: activeBold,
        isItalic: activeItalic,
        isStrike: activeStrike,
      ));
    }

    _normalizeSpans(newLen);
  }

  void _normalizeSpans(int textLength) {
    if (_spans.isEmpty) return;

    _spans.removeWhere((s) {
      s.start = s.start.clamp(0, textLength);
      s.end = s.end.clamp(0, textLength);
      return s.isEmpty;
    });

    if (_spans.length <= 1) return;

    _spans.sort((a, b) => a.start.compareTo(b.start));

    final List<FormattingSpan> merged = [];
    FormattingSpan current = _spans.first;

    for (int i = 1; i < _spans.length; i++) {
      final next = _spans[i];
      if (next.start <= current.end && current.hasSameStyle(next)) {
        current.end = math.max(current.end, next.end);
      } else {
        merged.add(current);
        current = next;
      }
    }
    merged.add(current);

    _spans.clear();
    _spans.addAll(merged);
  }

  void toggleBold() {
    if (selection.isValid && !selection.isCollapsed) {
      final start = math.min(selection.start, selection.end);
      final end = math.max(selection.start, selection.end);
      _toggleFormatForRange(start, end, bold: true);
    } else {
      activeBold = !activeBold;
    }
    notifyListeners();
  }

  void toggleItalic() {
    if (selection.isValid && !selection.isCollapsed) {
      final start = math.min(selection.start, selection.end);
      final end = math.max(selection.start, selection.end);
      _toggleFormatForRange(start, end, italic: true);
    } else {
      activeItalic = !activeItalic;
    }
    notifyListeners();
  }

  void toggleStrike() {
    if (selection.isValid && !selection.isCollapsed) {
      final start = math.min(selection.start, selection.end);
      final end = math.max(selection.start, selection.end);
      _toggleFormatForRange(start, end, strike: true);
    } else {
      activeStrike = !activeStrike;
    }
    notifyListeners();
  }

  void _toggleFormatForRange(int start, int end, {bool? bold, bool? italic, bool? strike}) {
    if (start >= end) return;

    bool isAlready = false;
    for (final s in _spans) {
      if (s.start <= start && s.end >= end) {
        if (bold == true && s.isBold) isAlready = true;
        if (italic == true && s.isItalic) isAlready = true;
        if (strike == true && s.isStrike) isAlready = true;
      }
    }

    if (isAlready) {
      for (final s in _spans) {
        if (s.start <= start && s.end >= end) {
          if (bold == true) s.isBold = false;
          if (italic == true) s.isItalic = false;
          if (strike == true) s.isStrike = false;
        }
      }
    } else {
      _spans.add(FormattingSpan(
        start: start,
        end: end,
        isBold: bold ?? false,
        isItalic: italic ?? false,
        isStrike: strike ?? false,
      ));
    }

    _normalizeSpans(text.length);
  }

  List<TextSpanNode> exportSpansForRange(int lineStart, int lineEnd) {
    final List<TextSpanNode> nodes = [];
    final currentText = text;
    if (lineStart >= lineEnd || lineStart >= currentText.length) {
      return nodes;
    }

    final int effectiveEnd = math.min(lineEnd, currentText.length);

    // Fast O(1) path: If no spans in document, return plain text node immediately
    if (_spans.isEmpty) {
      nodes.add(TextSpanNode(
        text: currentText.substring(lineStart, effectiveEnd),
        bold: false,
        italic: false,
        strikethrough: false,
      ));
      return nodes;
    }

    // Fast O(1) path: If no spans intersect [lineStart, effectiveEnd), return plain text node immediately
    final relevantSpans = _spans.where((s) => s.end > lineStart && s.start < effectiveEnd).toList();
    if (relevantSpans.isEmpty) {
      nodes.add(TextSpanNode(
        text: currentText.substring(lineStart, effectiveEnd),
        bold: false,
        italic: false,
        strikethrough: false,
      ));
      return nodes;
    }

    // Ultra-Fast O(M log M) interval sweep over span boundary points
    final boundarySet = <int>{lineStart, effectiveEnd};
    for (final s in relevantSpans) {
      boundarySet.add(s.start.clamp(lineStart, effectiveEnd));
      boundarySet.add(s.end.clamp(lineStart, effectiveEnd));
    }

    final boundaries = boundarySet.toList()..sort();

    for (int i = 0; i < boundaries.length - 1; i++) {
      final segStart = boundaries[i];
      final segEnd = boundaries[i + 1];
      if (segStart >= segEnd) continue;

      bool isB = false;
      bool isI = false;
      bool isS = false;

      for (final s in relevantSpans) {
        if (s.start <= segStart && s.end >= segEnd) {
          if (s.isBold) isB = true;
          if (s.isItalic) isI = true;
          if (s.isStrike) isS = true;
        }
      }

      nodes.add(TextSpanNode(
        text: currentText.substring(segStart, segEnd),
        bold: isB,
        italic: isI,
        strikethrough: isS,
      ));
    }

    return nodes;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    return PerformanceBenchmarkService.measure('build_text_span', () {
      final effectiveStyle = style ?? baseStyle;
      final currentText = text;

      if (currentText.isEmpty || _spans.isEmpty) {
        return TextSpan(style: effectiveStyle, text: currentText);
      }

      // High-performance single-pass linear O(M) sweep:
      // Only partitions text where styled spans exist, keeping plain text contiguous.
      final List<TextSpan> children = [];
      int cursor = 0;

      for (int i = 0; i < _spans.length; i++) {
        final s = _spans[i];
        final sStart = s.start.clamp(0, currentText.length);
        final sEnd = s.end.clamp(0, currentText.length);

        if (sStart > cursor) {
          children.add(TextSpan(
            text: currentText.substring(cursor, sStart),
            style: effectiveStyle,
          ));
        }

        if (sEnd > sStart && sEnd > cursor) {
          final actualStart = math.max(cursor, sStart);
          TextStyle segStyle = effectiveStyle;
          if (s.isBold) segStyle = segStyle.copyWith(fontWeight: FontWeight.w900);
          if (s.isItalic) segStyle = segStyle.copyWith(fontStyle: FontStyle.italic);
          if (s.isStrike) {
            segStyle = segStyle.copyWith(
              decoration: TextDecoration.lineThrough,
              color: (effectiveStyle.color ?? Colors.white).withValues(alpha: 0.7),
            );
          }
          children.add(TextSpan(
            text: currentText.substring(actualStart, sEnd),
            style: segStyle,
          ));
        }

        cursor = math.max(cursor, sEnd);
      }

      if (cursor < currentText.length) {
        children.add(TextSpan(
          text: currentText.substring(cursor),
          style: effectiveStyle,
        ));
      }

      return TextSpan(style: effectiveStyle, children: children);
    });
  }
}
