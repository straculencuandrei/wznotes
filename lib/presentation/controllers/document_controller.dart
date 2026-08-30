import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/note_document.dart';
import '../../domain/models/text_block.dart';
import '../../domain/models/vector_stroke.dart';
import '../../domain/models/canvas_template.dart';
import '../../domain/serialization/note_archive_manager.dart';

class DocumentNotifier extends StateNotifier<NoteDocument> {
  final List<NoteDocument> _undoStack = [];
  final List<NoteDocument> _redoStack = [];

  DocumentNotifier() : super(NoteDocument.initial());

  void _pushUndo() {
    _undoStack.add(state);
    if (_undoStack.length > 50) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void undo() {
    if (_undoStack.isNotEmpty) {
      _redoStack.add(state);
      state = _undoStack.removeLast();
    }
  }

  void redo() {
    if (_redoStack.isNotEmpty) {
      _undoStack.add(state);
      state = _redoStack.removeLast();
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
    _pushUndo();
    state = state.copyWith(
      metadata: state.metadata.copyWith(title: newTitle, modifiedAt: DateTime.now()),
    );
  }

  void setTemplate(CanvasTemplate template) {
    _pushUndo();
    state = state.copyWith(template: template);
  }

  void addStroke(VectorStroke stroke) {
    _pushUndo();
    state = state.copyWith(
      strokes: [...state.strokes, stroke],
    );
  }

  void deleteStrokes(List<String> strokeIds) {
    _pushUndo();
    state = state.copyWith(
      strokes: state.strokes.where((s) => !strokeIds.contains(s.id)).toList(),
    );
  }

  void recolorSelectedStrokes(List<String> strokeIds, Color newColor) {
    _pushUndo();
    state = state.copyWith(
      strokes: state.strokes.map((s) {
        if (strokeIds.contains(s.id)) {
          return s.copyWith(color: newColor);
        }
        return s;
      }).toList(),
    );
  }

  void duplicateStrokes(List<String> strokeIds, Offset offset) {
    _pushUndo();
    final toDup = state.strokes.where((s) => strokeIds.contains(s.id)).toList();
    final duplicated = toDup.map((s) {
      return s.copyWith(id: const Uuid().v4()).translate(offset);
    }).toList();

    state = state.copyWith(
      strokes: [...state.strokes, ...duplicated],
    );
  }

  // --- Text Block Operations (Infinite Writing) ---

  void addBlock(TextBlock block, {int? index}) {
    _pushUndo();
    final List<TextBlock> updated = List.from(state.blocks);
    if (index != null && index >= 0 && index <= updated.length) {
      updated.insert(index, block);
    } else {
      updated.add(block);
    }
    state = state.copyWith(blocks: updated).recalculateStats();
  }

  void updateBlock(String blockId, TextBlock updatedBlock) {
    _pushUndo();
    final updated = state.blocks.map((b) => b.id == blockId ? updatedBlock : b).toList();
    state = state.copyWith(blocks: updated).recalculateStats();
  }

  void deleteBlock(String blockId) {
    _pushUndo();
    final updated = state.blocks.where((b) => b.id != blockId).toList();
    state = state.copyWith(blocks: updated).recalculateStats();
  }

  void toggleChecklist(String blockId) {
    _pushUndo();
    final updated = state.blocks.map((b) {
      if (b.id == blockId) {
        return b.copyWith(isChecked: !b.isChecked);
      }
      return b;
    }).toList();
    state = state.copyWith(blocks: updated);
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
