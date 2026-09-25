import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wznotes/core/theme/app_themes.dart';
import 'package:wznotes/domain/models/note_document.dart';
import 'package:wznotes/domain/models/text_block.dart';
import 'package:wznotes/presentation/controllers/settings_controller.dart';
import 'package:wznotes/presentation/controllers/notes_library_controller.dart';

void main() {
  group('NoteMetadata Trash & 30-Day Auto-Purge Logic', () {
    test('Active note has isDeleted == false', () {
      final meta = NoteMetadata(
        id: 'note_1',
        title: 'Active Note',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      );

      expect(meta.isDeleted, isFalse);
      expect(meta.deletedAt, isNull);
    });

    test('Deleted note has isDeleted == true and calculates days remaining', () {
      final now = DateTime.now();
      final meta = NoteMetadata(
        id: 'note_2',
        title: 'Deleted Note',
        createdAt: now.subtract(const Duration(days: 10)),
        modifiedAt: now.subtract(const Duration(days: 5)),
        deletedAt: now.subtract(const Duration(days: 5)),
        folderId: 'trash',
      );

      expect(meta.isDeleted, isTrue);
      expect(meta.daysUntilPermanentDeletion, inInclusiveRange(24, 25));
    });

    test('Note deleted 30 days ago has 0 days until permanent deletion', () {
      final now = DateTime.now();
      final meta = NoteMetadata(
        id: 'note_3',
        title: 'Old Deleted Note',
        createdAt: now.subtract(const Duration(days: 40)),
        modifiedAt: now.subtract(const Duration(days: 31)),
        deletedAt: now.subtract(const Duration(days: 30)),
        folderId: 'trash',
      );

      expect(meta.isDeleted, isTrue);
      expect(meta.daysUntilPermanentDeletion, 0);
    });

    test('Restoring note clears deletedAt and folderId', () {
      final now = DateTime.now();
      final deletedMeta = NoteMetadata(
        id: 'note_4',
        title: 'Note to Restore',
        createdAt: now.subtract(const Duration(days: 2)),
        modifiedAt: now,
        deletedAt: now,
        folderId: 'trash',
      );

      final restoredMeta = deletedMeta.copyWith(
        folderId: '',
        clearDeletedAt: true,
        modifiedAt: DateTime.now(),
      );

      expect(restoredMeta.isDeleted, isFalse);
      expect(restoredMeta.deletedAt, isNull);
      expect(restoredMeta.folderId, '');
    });

    test('NoteMetadata json serialization preserves deletedAt', () {
      final now = DateTime.now();
      final meta = NoteMetadata(
        id: 'note_json',
        title: 'JSON Test',
        createdAt: now,
        modifiedAt: now,
        deletedAt: now,
        folderId: 'trash',
      );

      final json = meta.toJson();
      final deserialized = NoteMetadata.fromJson(json);

      expect(deserialized.id, meta.id);
      expect(deserialized.isDeleted, isTrue);
      expect(deserialized.folderId, 'trash');
      expect(deserialized.deletedAt, isNotNull);
    });
  });

  group('Curated AMOLED Themes Suite', () {
    test('AppThemes contains 12 curated dark AMOLED-friendly palettes', () {
      expect(AppThemes.allThemes.length, 12);
      final ids = AppThemes.allThemes.map((t) => t.id).toSet();
      expect(ids, containsAll([
        'amoled',
        'cyber',
        'nord',
        'forest',
        'sepia',
        'twilight',
        'crimson',
        'pacific',
        'solar',
        'gold',
        'dracula',
        'carbon',
      ]));
    });

    test('All themes have valid contrast backgrounds and accents', () {
      for (final theme in AppThemes.allThemes) {
        expect(theme.name.isNotEmpty, isTrue);
        expect(theme.description.isNotEmpty, isTrue);
        expect(theme.background, isNotNull);
        expect(theme.surface, isNotNull);
        expect(theme.accent, isNotNull);
        // All backgrounds must be ultra-dark (luminance < 0.05) to protect AMOLED displays
        expect(theme.background.computeLuminance(), lessThan(0.05));
      }
    });

    test('AppThemes.getTheme returns requested theme or falls back to amoled', () {
      expect(AppThemes.getTheme('cyber').name, 'Midnight Neon');
      expect(AppThemes.getTheme('nord').name, 'Nord Frost');
      expect(AppThemes.getTheme('forest').name, 'Forest Matrix');
      expect(AppThemes.getTheme('sepia').name, 'Warm Sepia');
      expect(AppThemes.getTheme('twilight').name, 'Royal Twilight');
      expect(AppThemes.getTheme('crimson').name, 'Crimson Velvet');
      expect(AppThemes.getTheme('pacific').name, 'Deep Pacific');
      expect(AppThemes.getTheme('solar').name, 'Solar Flare');
      expect(AppThemes.getTheme('gold').name, 'Golden Amber');
      expect(AppThemes.getTheme('dracula').name, 'Dracula Noir');
      expect(AppThemes.getTheme('carbon').name, 'Carbon Silver');
      expect(AppThemes.getTheme('unknown_id').id, 'amoled');
    });

    test('AppThemes.getThemeData produces valid Material3 dark ThemeData', () {
      for (final theme in AppThemes.allThemes) {
        final data = AppThemes.getThemeData(theme.id);
        expect(data.useMaterial3, isTrue);
        expect(data.brightness, Brightness.dark);
        expect(data.colorScheme.primary, theme.accent);
        expect(data.scaffoldBackgroundColor, theme.background);
      }
    });
  });

  group('SettingsController Theme & Word Count Integration', () {
    test('Default settings has themeId == amoled and showWordCount == true', () {
      const settings = AppSettingsState();
      expect(settings.themeId, 'amoled');
      expect(settings.showWordCount, isTrue);
    });

    test('AppSettingsState copyWith and serialization updates themeId and showWordCount', () {
      const initial = AppSettingsState();
      final updated = initial.copyWith(
        themeId: 'nord',
        showWordCount: false,
      );

      expect(updated.themeId, 'nord');
      expect(updated.showWordCount, isFalse);

      final json = updated.toJson();
      final restored = AppSettingsState.fromJson(json);

      expect(restored.themeId, 'nord');
      expect(restored.showWordCount, isFalse);
    });
  });

  group('NotesLibrary Soft-Delete & Trash Management', () {
    test('Filtering separates active notes from Trash notes', () {
      final now = DateTime.now();
      final activeNote = NoteDocument(
        metadata: NoteMetadata(id: 'active_1', title: 'Active Note', createdAt: now, modifiedAt: now),
        blocks: [const TextBlock(id: 'b1', type: TextBlockType.paragraph, rawText: 'Hello world active')],
      );
      final trashNote = NoteDocument(
        metadata: NoteMetadata(
          id: 'trash_1',
          title: 'Trash Note',
          createdAt: now.subtract(const Duration(days: 3)),
          modifiedAt: now,
          deletedAt: now,
          folderId: 'trash',
        ),
        blocks: [const TextBlock(id: 'b2', type: TextBlockType.paragraph, rawText: 'Deleted content')],
      );

      // In "All" category: only active note should be present
      final stateAll = NotesLibraryState(
        notes: [activeNote, trashNote],
        selectedCategory: 'All',
      );
      expect(stateAll.activeNotesCount, 1);
      expect(stateAll.trashCount, 1);
      expect(stateAll.filteredNotes.length, 1);
      expect(stateAll.filteredNotes.first.metadata.id, 'active_1');

      // In "Trash" category: only trash note should be present
      final stateTrash = NotesLibraryState(
        notes: [activeNote, trashNote],
        selectedCategory: 'Trash',
      );
      expect(stateTrash.filteredNotes.length, 1);
      expect(stateTrash.filteredNotes.first.metadata.id, 'trash_1');
    });
  });
}
