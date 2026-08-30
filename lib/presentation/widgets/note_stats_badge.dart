import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/document_controller.dart';

/// Small floating badge showing real-time word count and reading time
class NoteStatsBadge extends ConsumerWidget {
  const NoteStatsBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = ref.watch(documentProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.text_fields, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            '${doc.metadata.wordCount} words',
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          const Text('•', style: TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(width: 8),
          Text(
            '~${doc.metadata.readingTimeMinutes}m read',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
