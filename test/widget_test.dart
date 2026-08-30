import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wznotes/main.dart';

void main() {
  testWidgets('App smoke test initializes properly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: WzNotesApp(),
      ),
    );

    expect(find.text('All notes'), findsOneWidget);
  });
}
