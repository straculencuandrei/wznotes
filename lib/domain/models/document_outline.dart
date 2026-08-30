/// Table of Contents Heading Entry for long-form note navigation
class OutlineHeading {
  final String blockId;
  final int level; // 1 for H1, 2 for H2, 3 for H3
  final String title;
  final double estimatedYOffset;
  final int wordCountInSection;

  const OutlineHeading({
    required this.blockId,
    required this.level,
    required this.title,
    required this.estimatedYOffset,
    this.wordCountInSection = 0,
  });
}
