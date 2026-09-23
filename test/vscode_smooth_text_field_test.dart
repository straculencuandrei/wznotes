import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wznotes/presentation/widgets/vscode_smooth_text_field.dart';

void main() {
  group('VSCodeSmoothTextField comprehensive tests', () {
    testWidgets('Keeps Y constant during typing and smoothly animates X', (WidgetTester tester) async {
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
        expect(currentTop, equals(initialTop), reason: 'Y must remain strictly constant during typing!');
        
        await tester.pump(const Duration(milliseconds: 30));
        final midTop = _findCaretTop(tester);
        expect(midTop, equals(initialTop), reason: 'Y must not drift or dip mid-animation!');
        
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

      // Press Enter to create second line
      controller.text += '\nSecond line';
      controller.selection = TextSelection.collapsed(offset: controller.text.length);
      await tester.pump();

      final line2Top = _findCaretTop(tester)!;
      expect(line2Top, greaterThan(line1Top + 20.0), reason: 'Must jump immediately to line 2');
    });

    testWidgets('Backspace works cleanly without glitches', (WidgetTester tester) async {
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
  });
}

double? _findCaretTop(WidgetTester tester) {
  final finder = find.byType(Positioned);
  for (final el in finder.evaluate()) {
    final pos = el.widget as Positioned;
    if (pos.top != null) return pos.top;
  }
  return null;
}

double? _findCaretLeft(WidgetTester tester) {
  final finder = find.byType(Positioned);
  for (final el in finder.evaluate()) {
    final pos = el.widget as Positioned;
    if (pos.left != null) return pos.left;
  }
  return null;
}
