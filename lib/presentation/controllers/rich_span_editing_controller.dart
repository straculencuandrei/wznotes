import 'dart:math' as math;
import 'package:flutter/material.dart';

class FormattingSpan {
  int start;
  int end;
  bool isBold;
  bool isItalic;
  bool isStrike;
  bool isUnderline;

  FormattingSpan({
    required this.start,
    required this.end,
    this.isBold = false,
    this.isItalic = false,
    this.isStrike = false,
    this.isUnderline = false,
  });

  FormattingSpan copyWith({
    int? start,
    int? end,
    bool? isBold,
    bool? isItalic,
    bool? isStrike,
    bool? isUnderline,
  }) {
    return FormattingSpan(
      start: start ?? this.start,
      end: end ?? this.end,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isStrike: isStrike ?? this.isStrike,
      isUnderline: isUnderline ?? this.isUnderline,
    );
  }
}

/// Native WYSIWYG Span-Based Rich Text Controller
/// Maintains clean plain text and renders rich styling in real-time
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
    _parseInitialMarkdownSpans(text);
  }

  void _parseInitialMarkdownSpans(String raw) {
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
          _spans.add(FormattingSpan(start: startPos, end: endPos, isBold: true));
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
          _spans.add(FormattingSpan(start: startPos, end: endPos, isStrike: true));
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
          _spans.add(FormattingSpan(start: startPos, end: endPos, isItalic: true));
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
  }

  @override
  set value(TextEditingValue newValue) {
    _handleTextChange(_lastText, newValue.text, newValue.selection);
    _lastText = newValue.text;
    super.value = newValue;
  }

  void _handleTextChange(String oldText, String newText, TextSelection newSelection) {
    if (oldText == newText) return;

    final diff = newText.length - oldText.length;
    final int changePos = newSelection.baseOffset >= 0 ? newSelection.baseOffset : newText.length;

    if (diff > 0) {
      // Characters inserted at [insertStart, insertEnd)
      final int insertStart = math.max(0, changePos - diff);
      final int insertEnd = changePos;

      // Shift spans that appear after the insert point
      for (final span in _spans) {
        if (span.start >= insertStart) {
          span.start += diff;
          span.end += diff;
        } else if (span.end >= insertStart) {
          span.end += diff;
        }
      }

      // If active styling is active, format the newly typed character(s)
      if (activeBold || activeItalic || activeStrike) {
        _spans.add(FormattingSpan(
          start: insertStart,
          end: insertEnd,
          isBold: activeBold,
          isItalic: activeItalic,
          isStrike: activeStrike,
        ));
      }
    } else if (diff < 0) {
      // Characters deleted
      final int deleteStart = changePos;
      final int deleteCount = -diff;

      _spans.removeWhere((span) {
        if (span.start >= deleteStart && span.end <= deleteStart + deleteCount) {
          return true;
        }
        return false;
      });

      for (final span in _spans) {
        if (span.start >= deleteStart) {
          span.start = math.max(deleteStart, span.start - deleteCount);
          span.end = math.max(span.start, span.end - deleteCount);
        } else if (span.end > deleteStart) {
          span.end = math.max(span.start, span.end - deleteCount);
        }
      }
    }
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
    bool isAlreadyFormatted = false;
    for (final s in _spans) {
      if (s.start <= start && s.end >= end) {
        if (bold == true && s.isBold) isAlreadyFormatted = true;
        if (italic == true && s.isItalic) isAlreadyFormatted = true;
        if (strike == true && s.isStrike) isAlreadyFormatted = true;
      }
    }

    if (isAlreadyFormatted) {
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
  }

  /// Exports current text with markdown tags for saving
  String exportMarkdown() {
    final raw = text;
    if (raw.isEmpty || _spans.isEmpty) return raw;

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

    if (currentText.isEmpty) {
      return TextSpan(style: effectiveStyle, text: currentText);
    }

    if (_spans.isEmpty) {
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
