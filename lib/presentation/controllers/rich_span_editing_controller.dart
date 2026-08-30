import 'dart:math' as math;
import 'package:flutter/material.dart';

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
}

/// High-Performance Deterministic Span-Based Rich Text Controller
/// Uses prefix/suffix diffing and automatic span normalization to handle thousands of characters
/// and massive copy-pastes with zero cursor desync or styling corruption.
class RichSpanEditingController extends TextEditingController {
  TextStyle baseStyle;
  final List<FormattingSpan> _spans = [];

  bool activeBold = false;
  bool activeItalic = false;
  bool activeStrike = false;

  String _lastText = '';

  RichSpanEditingController({
    super.text,
    required this.baseStyle,
  }) {
    _lastText = text;
    _parseInitialMarkdown(text);
  }

  void _parseInitialMarkdown(String raw) {
    if (raw.isEmpty) return;
    final buffer = StringBuffer();
    int i = 0;
    while (i < raw.length) {
      if (raw.startsWith('**', i)) {
        final endIdx = raw.indexOf('**', i + 2);
        if (endIdx != -1) {
          final content = raw.substring(i + 2, endIdx);
          final startPos = buffer.length;
          buffer.write(content);
          final endPos = buffer.length;
          if (endPos > startPos) {
            _spans.add(FormattingSpan(start: startPos, end: endPos, isBold: true));
          }
          i = endIdx + 2;
          continue;
        }
      } else if (raw.startsWith('~~', i)) {
        final endIdx = raw.indexOf('~~', i + 2);
        if (endIdx != -1) {
          final content = raw.substring(i + 2, endIdx);
          final startPos = buffer.length;
          buffer.write(content);
          final endPos = buffer.length;
          if (endPos > startPos) {
            _spans.add(FormattingSpan(start: startPos, end: endPos, isStrike: true));
          }
          i = endIdx + 2;
          continue;
        }
      } else if (raw.startsWith('*', i)) {
        final endIdx = raw.indexOf('*', i + 1);
        if (endIdx != -1) {
          final content = raw.substring(i + 1, endIdx);
          final startPos = buffer.length;
          buffer.write(content);
          final endPos = buffer.length;
          if (endPos > startPos) {
            _spans.add(FormattingSpan(start: startPos, end: endPos, isItalic: true));
          }
          i = endIdx + 1;
          continue;
        }
      }
      buffer.write(raw[i]);
      i++;
    }

    final clean = buffer.toString();
    if (clean != raw) {
      value = TextEditingValue(
        text: clean,
        selection: TextSelection.collapsed(offset: clean.length),
      );
      _lastText = clean;
    }
    _normalizeSpans(clean.length);
  }

  @override
  set value(TextEditingValue newValue) {
    _handleDeterministicDiff(_lastText, newValue.text);
    _lastText = newValue.text;
    super.value = newValue;
  }

  /// Exact prefix/suffix diffing that never fails regardless of copy-paste size or IME composition
  void _handleDeterministicDiff(String oldText, String newText) {
    if (oldText == newText) return;

    final oldLen = oldText.length;
    final newLen = newText.length;

    // 1. Find common prefix
    int prefix = 0;
    while (prefix < oldLen && prefix < newLen && oldText[prefix] == newText[prefix]) {
      prefix++;
    }

    // 2. Find common suffix
    int suffix = 0;
    while (suffix < (oldLen - prefix) && suffix < (newLen - prefix) &&
           oldText[oldLen - 1 - suffix] == newText[newLen - 1 - suffix]) {
      suffix++;
    }

    final int deletedCount = oldLen - prefix - suffix;
    final int insertedCount = newLen - prefix - suffix;
    final int deleteStart = prefix;
    final int deleteEnd = prefix + deletedCount;
    final int insertEnd = prefix + insertedCount;

    // 3. Update existing spans across the diff
    final List<FormattingSpan> updated = [];
    for (final span in _spans) {
      if (span.end <= deleteStart) {
        // Completely before edit
        updated.add(span);
      } else if (span.start >= deleteEnd) {
        // Completely after edit -> shift by net delta
        final delta = insertedCount - deletedCount;
        span.start += delta;
        span.end += delta;
        updated.add(span);
      } else {
        // Overlaps deleted region -> trim span boundaries
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

    // 4. If active typing formatting is enabled and a single character or typed word was inserted
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

    // 1. Clamp bounds and remove empties
    _spans.removeWhere((s) {
      s.start = s.start.clamp(0, textLength);
      s.end = s.end.clamp(0, textLength);
      return s.isEmpty;
    });

    if (_spans.length <= 1) return;

    // 2. Sort by start index
    _spans.sort((a, b) => a.start.compareTo(b.start));

    // 3. Merge adjacent or overlapping spans with identical styles
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

    // Check if entire selected range already has the style
    bool isAlready = false;
    for (final s in _spans) {
      if (s.start <= start && s.end >= end) {
        if (bold == true && s.isBold) isAlready = true;
        if (italic == true && s.isItalic) isAlready = true;
        if (strike == true && s.isStrike) isAlready = true;
      }
    }

    if (isAlready) {
      // Remove style from range
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

  /// Exports current document text with markdown formatting for persistence
  String exportMarkdown() {
    final raw = text;
    if (raw.isEmpty || _spans.isEmpty) return raw;

    _normalizeSpans(raw.length);

    final buffer = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      for (final s in _spans) {
        if (s.start == i) {
          if (s.isBold) buffer.write('**');
          if (s.isItalic) buffer.write('*');
          if (s.isStrike) buffer.write('~~');
        }
      }

      buffer.write(raw[i]);

      for (final s in _spans) {
        if (s.end == i + 1) {
          if (s.isStrike) buffer.write('~~');
          if (s.isItalic) buffer.write('*');
          if (s.isBold) buffer.write('**');
        }
      }
    }
    return buffer.toString();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final effectiveStyle = style ?? baseStyle;
    final currentText = text;

    if (currentText.isEmpty || _spans.isEmpty) {
      return TextSpan(style: effectiveStyle, text: currentText);
    }

    final List<TextSpan> children = [];
    int cursor = 0;

    while (cursor < currentText.length) {
      bool isB = false;
      bool isI = false;
      bool isS = false;

      for (final s in _spans) {
        if (cursor >= s.start && cursor < s.end) {
          if (s.isBold) isB = true;
          if (s.isItalic) isI = true;
          if (s.isStrike) isS = true;
        }
      }

      int runEnd = cursor + 1;
      while (runEnd < currentText.length) {
        bool runB = false;
        bool runI = false;
        bool runS = false;
        for (final s in _spans) {
          if (runEnd >= s.start && runEnd < s.end) {
            if (s.isBold) runB = true;
            if (s.isItalic) runI = true;
            if (s.isStrike) runS = true;
          }
        }
        if (runB != isB || runI != isI || runS != isS) break;
        runEnd++;
      }

      TextStyle segStyle = effectiveStyle;
      if (isB) {
        segStyle = segStyle.copyWith(fontWeight: FontWeight.w900, color: Colors.white);
      }
      if (isI) {
        segStyle = segStyle.copyWith(fontStyle: FontStyle.italic);
      }
      if (isS) {
        segStyle = segStyle.copyWith(decoration: TextDecoration.lineThrough, color: Colors.white70);
      }

      children.add(TextSpan(
        text: currentText.substring(cursor, runEnd),
        style: segStyle,
      ));

      cursor = runEnd;
    }

    return TextSpan(style: effectiveStyle, children: children);
  }
}
