import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../controllers/document_controller.dart';

/// Collapsible Table of Contents Outline Drawer with AMOLED styling
class DocumentOutlineDrawer extends ConsumerWidget {
  final ScrollController scrollController;

  const DocumentOutlineDrawer({
    super.key,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = ref.watch(documentProvider);
    final outline = doc.generateOutline();

    return Drawer(
      backgroundColor: AppColors.amoledSurface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Icon(Icons.format_list_bulleted, color: AppColors.samsungOrange, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Table of Contents',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.amoledTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.amoledBorder),

            // Outline Entries List
            Expanded(
              child: outline.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text(
                          'No headings found.\nType # Heading 1 in your notes to generate an outline.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF666666), fontSize: 14, height: 1.5),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: outline.length,
                      itemBuilder: (context, index) {
                        final item = outline[index];
                        final double leftPad = (item.level - 1) * 16.0 + 16.0;

                        return ListTile(
                          contentPadding: EdgeInsets.only(left: leftPad, right: 16.0),
                          dense: true,
                          title: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: item.level == 1 ? 15 : 14,
                              fontWeight: item.level == 1 ? FontWeight.bold : FontWeight.w500,
                              color: item.level == 1 ? AppColors.amoledTextPrimary : const Color(0xFFB0B0B0),
                            ),
                          ),
                          subtitle: Text(
                            '~${item.wordCountInSection} words',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            scrollController.animateTo(
                              item.estimatedYOffset,
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOutCubic,
                            );
                          },
                        );
                      },
                    ),
            ),

            // Bottom Document Stats
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.amoledBorder)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${doc.metadata.wordCount} words',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.amoledTextSecondary),
                  ),
                  Text(
                    '~${doc.metadata.readingTimeMinutes} min read',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.amoledTextSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
