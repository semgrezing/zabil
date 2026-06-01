import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note_block_model.dart';
import '../services/notes_service.dart';
import 'notes_provider.dart';

String _generateId() =>
    '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';

class BlockEditorNotifier extends FamilyAsyncNotifier<List<NoteBlockModel>, String> {
  final Map<String, Timer> _debounceTimers = {};
  final Set<String> _dirtyBlockIds = {};
  bool _saving = false;

  NotesService get _service => ref.read(notesServiceProvider);
  String get _noteId => arg;

  @override
  Future<List<NoteBlockModel>> build(String arg) async {
    ref.onDispose(_disposeTimers);
    final note = await _service.getNoteById(arg);
    return note.blocks;
  }

  void _disposeTimers() {
    for (final t in _debounceTimers.values) {
      t.cancel();
    }
    _debounceTimers.clear();
  }

  bool get isSaving => _saving;

  void markBlockDirty(String blockId, String newContent) {
    state = state.whenData((blocks) =>
        blocks.map((b) => b.id == blockId ? b.copyWith(content: newContent) : b).toList());
    _dirtyBlockIds.add(blockId);
    _debounceTimers[blockId]?.cancel();
    _debounceTimers[blockId] = Timer(const Duration(milliseconds: 1500), () {
      _saveBlock(blockId);
    });
  }

  Future<void> _saveBlock(String blockId) async {
    if (!_dirtyBlockIds.contains(blockId)) return;
    final blocks = state.valueOrNull;
    if (blocks == null) return;
    final block = blocks.where((b) => b.id == blockId).firstOrNull;
    if (block == null) return;

    _dirtyBlockIds.remove(blockId);
    _saving = true;
    try {
      await _service.updateBlock(_noteId, blockId, content: block.content);
    } catch (_) {
      _dirtyBlockIds.add(blockId);
    }
    _saving = false;
  }

  Future<void> flushAll() async {
    for (final t in _debounceTimers.values) {
      t.cancel();
    }
    _debounceTimers.clear();
    final dirty = Set<String>.from(_dirtyBlockIds);
    for (final blockId in dirty) {
      await _saveBlock(blockId);
    }
  }

  Future<NoteBlockModel?> insertBlock(NoteBlockType type, int position, {String? content}) async {
    final defaultContent = content ?? _defaultContent(type);
    try {
      final block = await _service.createBlock(
        _noteId,
        type: type.name,
        content: defaultContent,
        position: position,
      );
      state = state.whenData((blocks) {
        final updated = blocks.map((b) {
          if (b.position >= position) return b.copyWith(position: b.position + 1);
          return b;
        }).toList()
          ..add(block)
          ..sort((a, b) => a.position.compareTo(b.position));
        return updated;
      });
      return block;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteBlock(String blockId) async {
    _debounceTimers[blockId]?.cancel();
    _debounceTimers.remove(blockId);
    _dirtyBlockIds.remove(blockId);

    final blocks = state.valueOrNull;
    if (blocks == null) return;
    final idx = blocks.indexWhere((b) => b.id == blockId);
    if (idx == -1) return;
    final removedPos = blocks[idx].position;

    state = state.whenData((blocks) {
      final updated = <NoteBlockModel>[];
      for (final b in blocks) {
        if (b.id == blockId) continue;
        if (b.position > removedPos) {
          updated.add(b.copyWith(position: b.position - 1));
        } else {
          updated.add(b);
        }
      }
      return updated;
    });

    try {
      await _service.deleteBlock(_noteId, blockId);
    } catch (_) {
      ref.invalidateSelf();
    }
  }

  Future<void> reorderBlocks(int oldIndex, int newIndex) async {
    final blocks = state.valueOrNull;
    if (blocks == null) return;

    final reordered = List<NoteBlockModel>.from(blocks);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);

    final updated = <NoteBlockModel>[];
    for (var i = 0; i < reordered.length; i++) {
      updated.add(reordered[i].copyWith(position: i));
    }
    state = AsyncValue.data(updated);

    try {
      await _service.reorderBlocks(_noteId, updated.map((b) => b.id).toList());
    } catch (_) {
      ref.invalidateSelf();
    }
  }

  void updateBlockLocally(String blockId, NoteBlockModel updated) {
    state = state.whenData(
        (blocks) => blocks.map((b) => b.id == blockId ? updated : b).toList());
  }

  void replaceAll(List<NoteBlockModel> blocks) {
    if (_dirtyBlockIds.isNotEmpty) return;
    state = AsyncValue.data(blocks);
  }

  String _defaultContent(NoteBlockType type) {
    switch (type) {
      case NoteBlockType.text:
        return jsonEncode({'delta': [{'insert': '\n'}]});
      case NoteBlockType.checklist:
        return jsonEncode({'items': [{'id': _generateId(), 'text': '', 'completed': false}]});
      case NoteBlockType.image:
        return '{}';
      case NoteBlockType.divider:
        return '{}';
    }
  }
}

final blockEditorProvider =
    AsyncNotifierProvider.family<BlockEditorNotifier, List<NoteBlockModel>, String>(
  BlockEditorNotifier.new,
);

final focusedBlockIdProvider = StateProvider<String?>((ref) => null);
