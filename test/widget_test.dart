import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wznotes/main.dart';
import 'package:wznotes/presentation/controllers/update_controller.dart';

class FakeUpdateNotifier extends UpdateNotifier {
  FakeUpdateNotifier() : super();

  @override
  Future<void> check({bool silent = false, String? customUrl}) async {
    state = state.copyWith(isChecking: false, checkedOnce: true);
  }
}

void main() {
  testWidgets('App smoke test initializes properly', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          updateProvider.overrideWith((ref) => FakeUpdateNotifier()),
        ],
        child: const WzNotesApp(),
      ),
    );

    expect(find.text('All notes'), findsOneWidget);
  });
}
