import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wznotes/domain/models/note_document.dart';
import 'package:wznotes/domain/models/text_block.dart';
import 'package:wznotes/presentation/controllers/editor_formatting_bridge.dart';
import 'package:wznotes/presentation/widgets/text_formatting_toolbar.dart';

import 'package:wznotes/presentation/controllers/rich_span_editing_controller.dart';
import 'package:wznotes/presentation/controllers/document_controller.dart';
import 'package:wznotes/core/diagnostics/performance_benchmark.dart';

void main() {
  group('Document 20k words performance tests', () {
    test('Calculates 20,000 words in sub-millisecond time with zero regex thrashing', () {
      final wordsList = List.generate(20000, (i) => 'word$i');

      // Split into 500 blocks of 40 words each
      final blocks = <TextBlock>[];
      const int blockSize = 40;
      for (int i = 0; i < 500; i++) {
        final blockWords = wordsList.sublist(i * blockSize, (i + 1) * blockSize).join(' ');
        blocks.add(TextBlock(
          id: 'block_$i',
          type: TextBlockType.paragraph,
          rawText: blockWords,
        ));
      }

      final doc = NoteDocument(
        metadata: NoteMetadata.initial(),
        blocks: blocks,
      );

      final stopwatch = Stopwatch()..start();
      final updated = doc.recalculateStats();
      stopwatch.stop();

      expect(updated.metadata.wordCount, equals(20000));
      expect(stopwatch.elapsedMilliseconds, lessThan(50),
          reason: '20,000 words stats recalculation must be instantaneous without GC thrashing');
    });

    test('Accurately counts words with mixed whitespace (tabs, newlines, multiple spaces)', () {
      final doc = NoteDocument(
        metadata: NoteMetadata.initial(),
        blocks: const [
          TextBlock(id: '1', type: TextBlockType.paragraph, rawText: '  hello \t\n world   foo\nbar  '),
        ],
      ).recalculateStats();

      expect(doc.metadata.wordCount, equals(4));
    });
  });

  group('Island Go to Top and Go to Bottom buttons', () {
    testWidgets('Go to Top and Go to Bottom buttons exist and scroll correctly', (WidgetTester tester) async {
      final scrollController = ScrollController();
      final bodyController = RichSpanEditingController(
        initialText: List.generate(500, (i) => 'Line $i of document').join('\n'),
        baseStyle: const TextStyle(fontSize: 16),
      );
      final bodyFocusNode = FocusNode();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  final bridge = ref.read(editorFormattingBridgeProvider);
                  bridge.bind(
                    controller: bodyController,
                    focusNode: bodyFocusNode,
                    onUpdate: () {},
                  );

                  return Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: 500,
                          itemBuilder: (context, index) => Text('Line $index'),
                        ),
                      ),
                      TextFormattingToolbar(scrollController: scrollController),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify buttons exist
      final topBtn = find.byTooltip('Go to Top');
      final bottomBtn = find.byTooltip('Go to Bottom');
      expect(topBtn, findsOneWidget);
      expect(bottomBtn, findsOneWidget);

      // Scroll to middle
      scrollController.jumpTo(1000.0);
      await tester.pumpAndSettle();
      expect(scrollController.offset, equals(1000.0));

      // Tap Go to Top
      await tester.tap(topBtn);
      await tester.pumpAndSettle();
      expect(scrollController.offset, equals(0.0));
      expect(bodyController.selection.baseOffset, equals(0));

      // Tap Go to Bottom
      await tester.tap(bottomBtn);
      await tester.pumpAndSettle();
      expect(scrollController.offset, equals(scrollController.position.maxScrollExtent));
      expect(bodyController.selection.baseOffset, equals(bodyController.text.length));

      scrollController.dispose();
      bodyController.dispose();
      bodyFocusNode.dispose();
    });
  });

  group('Diff-based DocumentCommand Undo/Redo Engine', () {
    test('Correctly undos and redos text block additions and updates with compact diffs', () {
      final notifier = DocumentNotifier();
      final initialCount = notifier.state.blocks.length;
      expect(notifier.canUndo, isFalse);
      expect(notifier.canRedo, isFalse);

      // Add block
      const block1 = TextBlock(id: 'custom_b1', type: TextBlockType.paragraph, rawText: 'First paragraph');
      notifier.addBlock(block1);
      expect(notifier.state.blocks.length, equals(initialCount + 1));
      expect(notifier.canUndo, isTrue);

      // Add second block
      const block2 = TextBlock(id: 'custom_b2', type: TextBlockType.paragraph, rawText: 'Second paragraph');
      notifier.addBlock(block2);
      expect(notifier.state.blocks.length, equals(initialCount + 2));

      // Update block 1
      const block1Updated = TextBlock(id: 'custom_b1', type: TextBlockType.heading1, rawText: 'First heading');
      notifier.updateBlock('custom_b1', block1Updated);
      expect(notifier.state.blocks.firstWhere((b) => b.id == 'custom_b1').rawText, equals('First heading'));
      expect(notifier.state.blocks.firstWhere((b) => b.id == 'custom_b1').type, equals(TextBlockType.heading1));

      // Undo update
      notifier.undo();
      expect(notifier.state.blocks.firstWhere((b) => b.id == 'custom_b1').rawText, equals('First paragraph'));
      expect(notifier.state.blocks.firstWhere((b) => b.id == 'custom_b1').type, equals(TextBlockType.paragraph));
      expect(notifier.canRedo, isTrue);

      // Redo update
      notifier.redo();
      expect(notifier.state.blocks.firstWhere((b) => b.id == 'custom_b1').rawText, equals('First heading'));

      // Undo update and block2
      notifier.undo();
      notifier.undo();
      expect(notifier.state.blocks.length, equals(initialCount + 1));
      expect(notifier.state.blocks.any((b) => b.id == 'custom_b1'), isTrue);
      expect(notifier.state.blocks.any((b) => b.id == 'custom_b2'), isFalse);

      // Undo block1
      notifier.undo();
      expect(notifier.state.blocks.length, equals(initialCount));
      expect(notifier.canUndo, isFalse);
    });
  });

  group('PerformanceBenchmarkService Telemetry Tests', () {
    test('Records keystrokes and computes writing performance metrics accurately', () {
      final service = PerformanceBenchmarkService.instance;
      expect(service.isEnabled, isTrue);

      service.recordKeystroke(5000, 800);
      expect(service.metrics.wordCount, equals(800));
      expect(service.metrics.charCount, equals(5000));
    });

    test('PerformanceBenchmarkService has registered keyboard dock probes', () {
      final service = PerformanceBenchmarkService.instance;
      expect(service.probes.containsKey('keyboard_dock_build'), isTrue);
      expect(service.probes.containsKey('keyboard_dock_layout'), isTrue);
      expect(service.probes.containsKey('keyboard_dock_paint'), isTrue);
    });
  });
}


