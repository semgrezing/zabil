import 'dart:convert';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/utils/haptics.dart';
import '../../models/note_block_model.dart';

class ChecklistBlockWidget extends StatefulWidget {
  final NoteBlockModel block;
  final ValueChanged<String> onContentChanged;
  final FocusNode focusNode;

  const ChecklistBlockWidget({
    super.key,
    required this.block,
    required this.onContentChanged,
    required this.focusNode,
  });

  @override
  State<ChecklistBlockWidget> createState() => _ChecklistBlockWidgetState();
}

class _ChecklistBlockWidgetState extends State<ChecklistBlockWidget> {
  late List<ChecklistBlockItem> _items;
  final _addCtrl = TextEditingController();
  final _addFocus = FocusNode();
  late final ConfettiController _confettiCtrl = ConfettiController(duration: const Duration(seconds: 2));

  @override
  void initState() {
    super.initState();
    _items = widget.block.checklistItems;
  }

  @override
  void didUpdateWidget(ChecklistBlockWidget old) {
    super.didUpdateWidget(old);
    if (old.block.id != widget.block.id) {
      _items = widget.block.checklistItems;
    }
  }

  void _emitChange() {
    final content = jsonEncode({
      'items': _items.map((i) => i.toJson()).toList(),
    });
    widget.onContentChanged(content);
  }

  void _toggleItem(int index) {
    final wasCompleted = _items[index].completed;
    setState(() {
      _items[index] = _items[index].copyWith(completed: !wasCompleted);
    });
    if (!wasCompleted) {
      Haptics.medium();
      if (_items.every((i) => i.completed)) {
        _confettiCtrl.play();
        Haptics.success();
      }
    } else {
      Haptics.light();
    }
    _emitChange();
  }

  void _updateText(int index, String text) {
    _items[index] = _items[index].copyWith(text: text);
    _emitChange();
  }

  void _deleteItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
    _emitChange();
  }

  void _addItem(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _items.add(ChecklistBlockItem(
        id: '${DateTime.now().millisecondsSinceEpoch}_${_items.length}',
        text: text.trim(),
        completed: false,
      ));
    });
    _addCtrl.clear();
    _emitChange();
    _addFocus.requestFocus();
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    _addCtrl.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            return _CheckItemTile(
              item: item,
              onToggle: () => _toggleItem(i),
              onTextChanged: (t) => _updateText(i, t),
              onDelete: () => _deleteItem(i),
            );
          }),
          Padding(
            padding: const EdgeInsets.only(left: 30, top: 4),
            child: TextField(
              controller: _addCtrl,
              focusNode: _addFocus,
              style: TextStyle(fontSize: 14, color: AppColors.fgSoft.withValues(alpha: 0.6)),
              decoration: InputDecoration(
                hintText: 'Добавить пункт...',
                hintStyle: TextStyle(color: AppColors.fgSoft.withValues(alpha: 0.3)),
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
              ),
              onSubmitted: _addItem,
            ),
          ),
        ],
      ),
      Positioned.fill(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiCtrl,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            emissionFrequency: 0.08,
            numberOfParticles: 15,
            maxBlastForce: 20,
            minBlastForce: 5,
            gravity: 0.15,
            colors: const [
              Color(0xFF69DB7C), Color(0xFF4DABF7), Color(0xFFFFD43B),
              Color(0xFFDA77F2), Color(0xFFF783AC),
            ],
          ),
        ),
      ),
      ],
      ),
    );
  }
}

class _CheckItemTile extends StatefulWidget {
  final ChecklistBlockItem item;
  final VoidCallback onToggle;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onDelete;

  const _CheckItemTile({
    required this.item,
    required this.onToggle,
    required this.onTextChanged,
    required this.onDelete,
  });

  @override
  State<_CheckItemTile> createState() => _CheckItemTileState();
}

class _CheckItemTileState extends State<_CheckItemTile> {
  bool _editing = false;
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.item.text);
  }

  @override
  void didUpdateWidget(_CheckItemTile old) {
    super.didUpdateWidget(old);
    if (old.item.text != widget.item.text && !_editing) {
      _ctrl.text = widget.item.text;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 36),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GestureDetector(
                onTap: widget.onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: widget.item.completed ? AppColors.white : Colors.transparent,
                    border: Border.all(
                      color: widget.item.completed ? AppColors.white : AppColors.fgSoft,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: widget.item.completed
                      ? const Icon(Icons.check, size: 14, color: AppColors.bg1)
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _editing
                    ? TextField(
                        controller: _ctrl,
                        autofocus: true,
                        style: const TextStyle(fontSize: 14, color: AppColors.white),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                        ),
                        onSubmitted: (t) {
                          widget.onTextChanged(t);
                          setState(() => _editing = false);
                        },
                        onTapOutside: (_) {
                          widget.onTextChanged(_ctrl.text);
                          setState(() => _editing = false);
                        },
                      )
                    : GestureDetector(
                        onDoubleTap: () => setState(() => _editing = true),
                        child: Text(
                          widget.item.text,
                          style: TextStyle(
                            fontSize: 14,
                            color: widget.item.completed ? AppColors.fgSoft : AppColors.white,
                            decoration: widget.item.completed ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: GestureDetector(
                onTap: widget.onDelete,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 14, color: AppColors.fgSoft.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
