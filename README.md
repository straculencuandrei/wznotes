# wznotes

A cross-platform note-taking application focused on long-form writing, journaling, and vector inking with pure AMOLED rendering.

## Features

- **Keyboard-First Writing**: Block-based rich text engine supporting headings (H1-H3), paragraphs, bullet lists, interactive checklists, blockquotes, and code blocks.
- **Markdown Shortcuts**: Live inline prefix expansion (`# `, `## `, `- `, `[] `).
- **Pure AMOLED Rendering**: Pitch-black (`#000000`) theme optimized for OLED displays with high-contrast typography.
- **Infinite Canvas**: Unbounded vertical viewport with dynamic expansion.
- **Vector Inking Engine**: Sub-16ms stylus pipeline with Catmull-Rom to Cubic Bézier spline smoothing, EMA pressure filtering, and hold-to-snap shape recognition.
- **Export Pipeline**: Direct export to Vector PDF, Markdown (.md), SVG, and open `.note` compressed archives (IEEE-754 binary strokes + JSON metadata).
- **Local Storage**: Offline-first architecture with SQLite FTS5 full-text search indexing.

## Architecture

```
lib/
├── core/
│   ├── constants/      # Dimensions, color tokens, typography scales
│   ├── math/           # Bézier splines, EMA pressure filter, shape recognizer, polygon lasso
│   └── theme/          # Material 3 AMOLED theme data
├── domain/
│   ├── models/         # Document, TextBlock, VectorStroke, CanvasTemplate, Outline
│   └── serialization/  # Packed binary codec (strokes.bin), Note JSON codec, ZIP archive manager
├── infrastructure/
│   ├── audio/          # Timecoded audio-to-ink synchronization service
│   ├── database/       # SQLite manager with FTS5 search index
│   └── export/         # Markdown, Vector PDF, and SVG exporters
└── presentation/
    ├── canvas/         # Viewport, active stroke painter, tile painter, lasso painter
    ├── controllers/    # Riverpod state notifiers (document, library, inking, text editor, theme)
    ├── screens/        # Notes library (home) and Note editor
    └── widgets/        # Keyboard accessory toolbar, floating dock, outline drawer
```

## Getting Started

### Prerequisites

- Flutter SDK (>= 3.22.0)
- Android SDK (API level 26+)
- JDK 17

### Installation & Run

```bash
# Get dependencies
flutter pub get

# Run unit and serialization tests
flutter test

# Run on connected Android device / emulator
flutter run

# Run on Windows Desktop
flutter run -d windows
```

## Binary Note Container Specification

Notes are packaged as standard `.note` ZIP archives containing:
- `manifest.json`: Container format version and schema definition.
- `metadata.json`: Note ID, timestamps, tags, word counts, and statistics.
- `document.json`: Structured array of text blocks and span nodes.
- `strokes.bin`: Packed binary format (float32 coordinates/pressure, uint16 timestamps/colors).
- `strokes.json`: Interoperable JSON fallback for stroke geometries.
- `assets/`: Embedded images and synchronized audio recordings.
