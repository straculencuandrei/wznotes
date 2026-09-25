import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/note_document.dart';
import '../../domain/models/text_block.dart';
import '../../domain/models/vector_stroke.dart';
import '../../domain/models/canvas_template.dart';
import '../../domain/serialization/note_archive_manager.dart';

/// Abstract Diff-based Document Command for memory-compact undo/redo history.
/// Prevents holding 50 deep clones of 20k-60k word document trees in memory.
abstract class DocumentCommand {
  NoteDocument apply(NoteDocument doc);
  NoteDocument revert(NoteDocument doc);
}

class _TitleCommand implements DocumentCommand {
  final String oldTitle;
  final String newTitle;
  _TitleCommand(this.oldTitle, this.newTitle);

  @override
  NoteDocument apply(NoteDocument doc) => doc.copyWith(
        metadata: doc.metadata.copyWith(title: newTitle, modifiedAt: DateTime.now()),
      );

  @override
  NoteDocument revert(NoteDocument doc) => doc.copyWith(
        metadata: doc.metadata.copyWith(title: oldTitle, modifiedAt: DateTime.now()),
      );
}

class _TemplateCommand implements DocumentCommand {
  final CanvasTemplate oldTemplate;
  final CanvasTemplate newTemplate;
  _TemplateCommand(this.oldTemplate, this.newTemplate);

  @override
  NoteDocument apply(NoteDocument doc) => doc.copyWith(template: newTemplate);

  @override
  NoteDocument revert(NoteDocument doc) => doc.copyWith(template: oldTemplate);
}

class _AddStrokeCommand implements DocumentCommand {
  final VectorStroke stroke;
  _AddStrokeCommand(this.stroke);

  @override
  NoteDocument apply(NoteDocument doc) => doc.copyWith(
        strokes: [...doc.strokes, stroke],
      );

  @override
  NoteDocument revert(NoteDocument doc) => doc.copyWith(
        strokes: doc.strokes.where((s) => s.id != stroke.id).toList(),
      );
}

class _DeleteStrokesCommand implements DocumentCommand {
  final List<VectorStroke> removedStrokes;
  _DeleteStrokesCommand(this.removedStrokes);

  @override
  NoteDocument apply(NoteDocument doc) {
    final ids = removedStrokes.map((s) => s.id).toSet();
    return doc.copyWith(
      strokes: doc.strokes.where((s) => !ids.contains(s.id)).toList(),
    );
  }

  @override
  NoteDocument revert(NoteDocument doc) => doc.copyWith(
        strokes: [...doc.strokes, ...removedStrokes],
      );
}

class _RecolorStrokesCommand implements DocumentCommand {
  final Map<String, Color> oldColors;
  final Color newColor;
  _RecolorStrokesCommand(this.oldColors, this.newColor);

  @override
  NoteDocument apply(NoteDocument doc) {
    final ids = oldColors.keys.toSet();
    return doc.copyWith(
      strokes: doc.strokes.map((s) => ids.contains(s.id) ? s.copyWith(color: newColor) : s).toList(),
    );
  }

  @override
  NoteDocument revert(NoteDocument doc) {
    return doc.copyWith(
      strokes: doc.strokes.map((s) => oldColors.containsKey(s.id) ? s.copyWith(color: oldColors[s.id]!) : s).toList(),
    );
  }
}

class _DuplicateStrokesCommand implements DocumentCommand {
  final List<VectorStroke> duplicatedStrokes;
  _DuplicateStrokesCommand(this.duplicatedStrokes);

  @override
  NoteDocument apply(NoteDocument doc) => doc.copyWith(
        strokes: [...doc.strokes, ...duplicatedStrokes],
      );

  @override
  NoteDocument revert(NoteDocument doc) {
    final ids = duplicatedStrokes.map((s) => s.id).toSet();
    return doc.copyWith(
      strokes: doc.strokes.where((s) => !ids.contains(s.id)).toList(),
    );
  }
}

class _AddBlockCommand implements DocumentCommand {
  final TextBlock block;
  final int index;
  _AddBlockCommand(this.block, this.index);

  @override
  NoteDocument apply(NoteDocument doc) {
    final list = List<TextBlock>.from(doc.blocks);
    if (index >= 0 && index <= list.length) {
      list.insert(index, block);
    } else {
      list.add(block);
    }
    return doc.copyWith(blocks: list).recalculateStats();
  }

  @override
  NoteDocument revert(NoteDocument doc) {
    final list = doc.blocks.where((b) => b.id != block.id).toList();
    return doc.copyWith(blocks: list).recalculateStats();
  }
}

class _UpdateBlockCommand implements DocumentCommand {
  final TextBlock oldBlock;
  final TextBlock newBlock;
  _UpdateBlockCommand(this.oldBlock, this.newBlock);

  @override
  NoteDocument apply(NoteDocument doc) {
    final list = doc.blocks.map((b) => b.id == oldBlock.id ? newBlock : b).toList();
    return doc.copyWith(blocks: list).recalculateStats();
  }

  @override
  NoteDocument revert(NoteDocument doc) {
    final list = doc.blocks.map((b) => b.id == oldBlock.id ? oldBlock : b).toList();
    return doc.copyWith(blocks: list).recalculateStats();
  }
}

class _DeleteBlockCommand implements DocumentCommand {
  final TextBlock removedBlock;
  final int index;
  _DeleteBlockCommand(this.removedBlock, this.index);

  @override
  NoteDocument apply(NoteDocument doc) {
    final list = doc.blocks.where((b) => b.id != removedBlock.id).toList();
    return doc.copyWith(blocks: list).recalculateStats();
  }

  @override
  NoteDocument revert(NoteDocument doc) {
    final list = List<TextBlock>.from(doc.blocks);
    if (index >= 0 && index <= list.length) {
      list.insert(index, removedBlock);
    } else {
      list.add(removedBlock);
    }
    return doc.copyWith(blocks: list).recalculateStats();
  }
}

class _ToggleChecklistCommand implements DocumentCommand {
  final String blockId;
  _ToggleChecklistCommand(this.blockId);

  @override
  NoteDocument apply(NoteDocument doc) {
    final list = doc.blocks.map((b) {
      if (b.id == blockId) {
        return b.copyWith(isChecked: !b.isChecked);
      }
      return b;
    }).toList();
    return doc.copyWith(blocks: list);
  }

  @override
  NoteDocument revert(NoteDocument doc) => apply(doc);
}

class DocumentNotifier extends StateNotifier<NoteDocument> {
  final List<DocumentCommand> _undoStack = [];
  final List<DocumentCommand> _redoStack = [];

  DocumentNotifier() : super(NoteDocument.initial());

  void _pushCommand(DocumentCommand cmd) {
    state = cmd.apply(state);
    _undoStack.add(cmd);
    if (_undoStack.length > 50) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void undo() {
    if (_undoStack.isNotEmpty) {
      final cmd = _undoStack.removeLast();
      state = cmd.revert(state);
      _redoStack.add(cmd);
    }
  }

  void redo() {
    if (_redoStack.isNotEmpty) {
      final cmd = _redoStack.removeLast();
      state = cmd.apply(state);
      _undoStack.add(cmd);
    }
  }

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void setDocument(NoteDocument doc) {
    _undoStack.clear();
    _redoStack.clear();
    state = doc;
  }

  void updateContent({required String title, required List<TextBlock> blocks}) {
    state = state.copyWith(
      metadata: state.metadata.copyWith(title: title),
      blocks: blocks,
    ).recalculateStats();
  }

  // --- Document Operations ---

  void setTitle(String newTitle) {
    _pushCommand(_TitleCommand(state.metadata.title, newTitle));
  }

  void setTemplate(CanvasTemplate template) {
    _pushCommand(_TemplateCommand(state.template, template));
  }

  void addStroke(VectorStroke stroke) {
    _pushCommand(_AddStrokeCommand(stroke));
  }

  void deleteStrokes(List<String> strokeIds) {
    final removed = state.strokes.where((s) => strokeIds.contains(s.id)).toList();
    if (removed.isNotEmpty) {
      _pushCommand(_DeleteStrokesCommand(removed));
    }
  }

  void recolorSelectedStrokes(List<String> strokeIds, Color newColor) {
    final oldColors = <String, Color>{};
    for (final s in state.strokes) {
      if (strokeIds.contains(s.id)) {
        oldColors[s.id] = s.color;
      }
    }
    if (oldColors.isNotEmpty) {
      _pushCommand(_RecolorStrokesCommand(oldColors, newColor));
    }
  }

  void duplicateStrokes(List<String> strokeIds, Offset offset) {
    final toDup = state.strokes.where((s) => strokeIds.contains(s.id)).toList();
    final duplicated = toDup.map((s) {
      return s.copyWith(id: const Uuid().v4()).translate(offset);
    }).toList();

    if (duplicated.isNotEmpty) {
      _pushCommand(_DuplicateStrokesCommand(duplicated));
    }
  }

  // --- Text Block Operations (Infinite Writing) ---

  void addBlock(TextBlock block, {int? index}) {
    final targetIndex = (index != null && index >= 0 && index <= state.blocks.length)
        ? index
        : state.blocks.length;
    _pushCommand(_AddBlockCommand(block, targetIndex));
  }

  void updateBlock(String blockId, TextBlock updatedBlock) {
    final oldIndex = state.blocks.indexWhere((b) => b.id == blockId);
    if (oldIndex != -1) {
      _pushCommand(_UpdateBlockCommand(state.blocks[oldIndex], updatedBlock));
    }
  }

  void deleteBlock(String blockId) {
    final index = state.blocks.indexWhere((b) => b.id == blockId);
    if (index != -1) {
      _pushCommand(_DeleteBlockCommand(state.blocks[index], index));
    }
  }

  void toggleChecklist(String blockId) {
    _pushCommand(_ToggleChecklistCommand(blockId));
  }

  /// Loads document from `.note` archive file
  Future<void> loadFromArchive(String filePath) async {
    final doc = await NoteArchiveManager.loadFromFile(filePath);
    _undoStack.clear();
    _redoStack.clear();
    state = doc;
  }

  /// Saves document to `.note` archive file
  Future<void> saveToArchive(String filePath) async {
    await NoteArchiveManager.saveToFile(state, filePath);
  }
}

final documentProvider = StateNotifierProvider<DocumentNotifier, NoteDocument>((ref) {
  return DocumentNotifier();
});
