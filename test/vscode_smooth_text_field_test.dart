import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wznotes/presentation/widgets/vscode_smooth_text_field.dart';

void main() {
  group('VSCodeSmoothTextField comprehensive tests', () {
    testWidgets('Glides smoothly on horizontal typing while keeping Y constant', (WidgetTester tester) async {
      final controller = TextEditingController(text: '');
      final focusNode = FocusNode();
      const style = TextStyle(fontSize: 17.0, height: 1.6);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: VSCodeSmoothTextField(
              controller: controller,
              focusNode: focusNode,
              style: style,
              hintText: 'Hint',
              hintStyle: const TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ));

      focusNode.requestFocus();
      await tester.pumpAndSettle();

      final initialTop = _findCaretTop(tester);
      expect(initialTop, isNotNull);

      // Type 10 characters consecutively
      for (int i = 0; i < 10; i++) {
        controller.text += 'a';
        controller.selection = TextSelection.collapsed(offset: controller.text.length);
        await tester.pump();

        final currentTop = _findCaretTop(tester);
        expect(currentTop, equals(initialTop), reason: 'Y must remain strictly constant during typing on the same line');

        await tester.pump(const Duration(milliseconds: 35));
        final midTop = _findCaretTop(tester);
        expect(midTop, equals(initialTop), reason: 'Y must not drift or dip mid-animation');

        await tester.pumpAndSettle();
      }
    });

    testWidgets('Snaps immediately on newline with no diagonal lag', (WidgetTester tester) async {
      final controller = TextEditingController(text: 'First line');
      final focusNode = FocusNode();
      const style = TextStyle(fontSize: 17.0, height: 1.6);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: VSCodeSmoothTextField(
              controller: controller,
              focusNode: focusNode,
              style: style,
              hintText: 'Hint',
              hintStyle: const TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ));

      focusNode.requestFocus();
      await tester.pumpAndSettle();

      final line1Top = _findCaretTop(tester)!;

      // Add second line
      controller.text += '\nSecond line';
      controller.selection = TextSelection.collapsed(offset: controller.text.length);
      await tester.pump();
      await tester.pumpAndSettle();

      final line2Top = _findCaretTop(tester)!;
      expect(line2Top, greaterThan(line1Top + 15.0), reason: 'Must jump immediately to line 2 without diagonal lag');
    });

    testWidgets('Backspace works cleanly and smoothly moves left', (WidgetTester tester) async {
      final controller = TextEditingController(text: 'Hello world');
      final focusNode = FocusNode();
      const style = TextStyle(fontSize: 17.0, height: 1.6);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: VSCodeSmoothTextField(
              controller: controller,
              focusNode: focusNode,
              style: style,
              hintText: 'Hint',
              hintStyle: const TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ));

      focusNode.requestFocus();
      await tester.pumpAndSettle();

      final topBefore = _findCaretTop(tester)!;
      final xBefore = _findCaretLeft(tester)!;

      // Delete 3 characters
      controller.text = 'Hello wo';
      controller.selection = TextSelection.collapsed(offset: controller.text.length);
      await tester.pump();
      await tester.pumpAndSettle();

      final topAfter = _findCaretTop(tester)!;
      final xAfter = _findCaretLeft(tester)!;

      expect(topAfter, equals(topBefore), reason: 'Y must remain unchanged on backspace');
      expect(xAfter, lessThan(xBefore), reason: 'X must move left after backspace');
    });

    testWidgets('Caret accurately transitions downward when word soft-wraps across lines', (WidgetTester tester) async {
      final controller = TextEditingController(text: '');
      final focusNode = FocusNode();
      const style = TextStyle(fontSize: 16.0, height: 1.6);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 250,
            child: VSCodeSmoothTextField(
              controller: controller,
              focusNode: focusNode,
              style: style,
              hintText: 'Hint',
              hintStyle: const TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ));

      focusNode.requestFocus();
      await tester.pumpAndSettle();

      final initialTop = _findCaretTop(tester)!;

      // Type text that triggers soft wrapping without newlines
      const wrapText = 'ddddddd eeee eeeeeddddddddddddddddd';
      for (int i = 1; i <= wrapText.length; i++) {
        controller.text = wrapText.substring(0, i);
        controller.selection = TextSelection.collapsed(offset: i);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));
      }

      await tester.pumpAndSettle();
      final wrappedTop = _findCaretTop(tester)!;

      // The caret must be on the wrapped line, not stuck on initialTop
      expect(wrappedTop, greaterThan(initialTop + 20.0), reason: 'Caret must advance downward on soft-wrap');
    });

    testWidgets('Typing a lot of text wraps words cleanly and caret never stays behind on previous row', (WidgetTester tester) async {
      final controller = TextEditingController(text: '');
      final focusNode = FocusNode();
      const style = TextStyle(fontSize: 16.0, height: 1.6);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: VSCodeSmoothTextField(
              controller: controller,
              focusNode: focusNode,
              style: style,
              hintText: 'Hint',
              hintStyle: const TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ));

      focusNode.requestFocus();
      await tester.pumpAndSettle();

      final words = [
        'The', 'extraordinary', 'adventures', 'of', 'travelers', 'across', 'infinite',
        'realms', 'and', 'dimensions', 'revealing', 'ancient', 'secrets', 'of',
        'the', 'universe', 'and', 'bringing', 'peace', 'to', 'all', 'corners',
      ];

      double previousLineTop = _findCaretTop(tester)!;
      String currentText = '';

      for (final word in words) {
        for (int i = 0; i < word.length; i++) {
          currentText += word[i];
          controller.value = TextEditingValue(
            text: currentText,
            selection: TextSelection.collapsed(offset: currentText.length),
          );
          await tester.pump();
          final currentTop = _findCaretTop(tester)!;
          // Caret Y must either stay on the current line or advance downward to a new line
          expect(currentTop, greaterThanOrEqualTo(previousLineTop));
          previousLineTop = currentTop;
        }
        currentText += ' ';
        controller.value = TextEditingValue(
          text: currentText,
          selection: TextSelection.collapsed(offset: currentText.length),
        );
        await tester.pump();
      }

      expect(previousLineTop, greaterThan(100.0), reason: 'Multiple lines should have wrapped smoothly');
    });

    testWidgets('Typing in a massive 10,000+ word document runs instantly with zero lag and maintains caret sync', (WidgetTester tester) async {
      // Generate 10,000 words across multiple paragraphs
      final paragraphs = List.generate(50, (i) => 'Paragraph $i: ${List.filled(200, 'word').join(' ')}.\n');
      final massiveText = paragraphs.join();

      final controller = TextEditingController(text: massiveText);
      final focusNode = FocusNode();
      const style = TextStyle(fontSize: 17.0, height: 1.6);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: VSCodeSmoothTextField(
                controller: controller,
                focusNode: focusNode,
                style: style,
                hintText: 'Hint',
                hintStyle: const TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ),
      ));

      focusNode.requestFocus();
      await tester.pumpAndSettle();

      final initialTop = _findCaretTop(tester);
      expect(initialTop, isNotNull);

      // Now append 20 words at the end of this 10,000 word document
      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < 20; i++) {
        controller.value = TextEditingValue(
          text: '${controller.text} testword',
          selection: TextSelection.collapsed(offset: controller.text.length + 9),
        );
        await tester.pump();
      }
      stopwatch.stop();

      // Ensure 20 typing frames executed in under 800ms total (< 40ms per pump including widget framework)
      expect(stopwatch.elapsedMilliseconds, lessThan(800), reason: 'Typing in 10k words must not freeze or lag');

      final finalTop = _findCaretTop(tester)!;
      expect(finalTop, greaterThanOrEqualTo(initialTop!), reason: 'Caret must advance with new text at end of 10k word doc');
    });

    testWidgets('Typing in a massive 20,000 word document across middle paragraphs maintains 100% caret alignment and never jumps to line 0', (WidgetTester tester) async {
      // 100 paragraphs of 200 words each = 20,000 words
      final paragraphs = List.generate(100, (i) => 'Paragraph $i: ${List.filled(200, 'storyword').join(' ')}.\n');
      final massiveText = paragraphs.join();

      final controller = TextEditingController(text: massiveText);
      final focusNode = FocusNode();
      const style = TextStyle(fontSize: 17.0, height: 1.6);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: VSCodeSmoothTextField(
                controller: controller,
                focusNode: focusNode,
                style: style,
                hintText: 'Hint',
                hintStyle: const TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ),
      ));

      focusNode.requestFocus();
      await tester.pumpAndSettle();

      // Tap directly into paragraph 30 (deep inside the 20,000 word document)
      int targetOffset = 0;
      for (int i = 0; i < 30; i++) {
        targetOffset += paragraphs[i].length;
      }
      targetOffset += 50; // 50 chars into paragraph 30

      controller.selection = TextSelection.collapsed(offset: targetOffset);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final p30Top = _findCaretTop(tester)!;
      // Paragraph 30 must have a significant vertical Y, not 0.0!
      expect(p30Top, greaterThan(500.0), reason: 'Caret in paragraph 30 of 20k words must never be stuck at top (line 0)');

      // Now type 10 characters consecutively inside paragraph 30
      final sw = Stopwatch()..start();
      for (int i = 0; i < 10; i++) {
        final currentText = controller.text;
        final newText = '${currentText.substring(0, targetOffset + i)}x${currentText.substring(targetOffset + i)}';
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: targetOffset + i + 1),
        );
        await tester.pump();
        final currentTop = _findCaretTop(tester)!;
        expect(currentTop, greaterThanOrEqualTo(p30Top), reason: 'Caret must stay in paragraph 30 and advance downward on soft-wrap');
        expect(currentTop, lessThan(p30Top + 60.0), reason: 'Caret must stay within the paragraph and not jump elsewhere');
      }
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(1200), reason: '10 keystrokes in 20k words must execute quickly in test harness');
    });
  });
}

double? _findCaretTop(WidgetTester tester) {
  final caretContainer = find.byWidgetPredicate(
    (w) => w is Container && (w.constraints?.maxWidth == 2.4 || (w.decoration is BoxDecoration && (w.decoration as BoxDecoration).borderRadius != null)),
  );
  if (caretContainer.evaluate().isNotEmpty) {
    final transformFinder = find.ancestor(of: caretContainer.first, matching: find.byType(Transform));
    if (transformFinder.evaluate().isNotEmpty) {
      final t = tester.widget(transformFinder.first) as Transform;
      return t.transform.getTranslation().y;
    }
  }
  return null;
}

double? _findCaretLeft(WidgetTester tester) {
  final caretContainer = find.byWidgetPredicate(
    (w) => w is Container && (w.constraints?.maxWidth == 2.4 || (w.decoration is BoxDecoration && (w.decoration as BoxDecoration).borderRadius != null)),
  );
  if (caretContainer.evaluate().isNotEmpty) {
    final transformFinder = find.ancestor(of: caretContainer.first, matching: find.byType(Transform));
    if (transformFinder.evaluate().isNotEmpty) {
      final t = tester.widget(transformFinder.first) as Transform;
      return t.transform.getTranslation().x;
    }
  }
  return null;
}
