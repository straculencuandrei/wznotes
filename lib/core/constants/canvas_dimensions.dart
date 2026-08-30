/// Infinite Canvas & Spatial Chunking Dimensions
class CanvasDimensions {
  /// Standard page width for desktop & tablet reading measure (in logical points)
  static const double defaultDocumentWidth = 820.0;

  /// Default line spacing for ruled/lined paper templates (28.0 pt matches standard 1.75 text line-height)
  static const double defaultRuledLineSpacing = 28.0;

  /// Default grid size for grid paper templates
  static const double defaultGridSpacing = 28.0;

  /// Default dot spacing for dotted bullet journal templates
  static const double defaultDotSpacing = 28.0;

  /// Spatial Tile Chunk Height for Infinite Canvas (prevents GPU Skia max texture limits)
  static const double spatialChunkHeight = 2000.0;

  /// Initial canvas virtual height allocated on startup (expands dynamically downwards to infinity)
  static const double initialInfiniteHeight = 4000.0;

  /// Buffer distance to auto-expand infinite canvas when user scrolls or draws near the bottom
  static const double autoExpandThreshold = 1000.0;

  /// Minimum and Maximum Canvas Zoom Constraints
  static const double minZoom = 0.35;
  static const double maxZoom = 4.0;

  /// Standard A4 Dimensions in points (72 pt per inch)
  static const double a4Width = 595.28;
  static const double a4Height = 841.89;

  /// Standard US Letter Dimensions in points
  static const double letterWidth = 612.0;
  static const double letterHeight = 792.0;
}
