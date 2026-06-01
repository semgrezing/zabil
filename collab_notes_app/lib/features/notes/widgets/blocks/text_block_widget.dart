import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../models/note_block_model.dart';

class TextBlockWidget extends StatefulWidget {
  final NoteBlockModel block;
  final ValueChanged<String> onContentChanged;
  final VoidCallback? onSlashTyped;
  final VoidCallback? onEmpty;
  final FocusNode focusNode;

  const TextBlockWidget({
    super.key,
    required this.block,
    required this.onContentChanged,
    required this.focusNode,
    this.onSlashTyped,
    this.onEmpty,
  });

  @override
  State<TextBlockWidget> createState() => _TextBlockWidgetState();
}

class _TextBlockWidgetState extends State<TextBlockWidget> {
  late QuillController _controller;
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    try {
      final ops = widget.block.deltaOps;
      _controller = QuillController(
        document: Document.fromJson(ops),
        selection: const TextSelection.collapsed(offset: 0),
      );
    } catch (_) {
      _controller = QuillController.basic();
    }
    _controller.addListener(_onEdit);
    _hydrated = true;
  }

  @override
  void didUpdateWidget(TextBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.id != widget.block.id) {
      _controller.removeListener(_onEdit);
      _controller.dispose();
      _initController();
    }
  }

  void _onEdit() {
    final delta = _controller.document.toDelta().toJson();
    final content = jsonEncode({'delta': delta});
    widget.onContentChanged(content);

    if (widget.onSlashTyped != null) {
      final text = _controller.document.toPlainText();
      final offset = _controller.selection.baseOffset;
      if (offset > 0 && offset <= text.length) {
        final charBefore = text[offset - 1];
        if (charBefore == '/') {
          final lineStart = text.lastIndexOf('\n', offset - 2) + 1;
          final lineBeforeSlash = text.substring(lineStart, offset - 1).trim();
          if (lineBeforeSlash.isEmpty) {
            widget.onSlashTyped!();
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onEdit);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hydrated) return const SizedBox.shrink();

    return QuillEditor.basic(
      controller: _controller,
      focusNode: widget.focusNode,
      config: QuillEditorConfig(
        placeholder: 'Текст...',
        padding: EdgeInsets.zero,
        autoFocus: false,
        expands: false,
        scrollable: false,
        customStyles: _darkStyles(),
      ),
    );
  }

  QuillController get controller => _controller;

  DefaultStyles _darkStyles() {
    const white = AppColors.white;
    const soft = AppColors.fgSoft;
    const noSpacing = VerticalSpacing(0, 0);
    const blockSpacing = VerticalSpacing(8, 0);
    const hSpacing = HorizontalSpacing(0, 0);

    return DefaultStyles(
      h1: DefaultTextBlockStyle(
        TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: white, height: 1.3),
        hSpacing, blockSpacing, noSpacing, null,
      ),
      h2: DefaultTextBlockStyle(
        TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: white, height: 1.3),
        hSpacing, blockSpacing, noSpacing, null,
      ),
      h3: DefaultTextBlockStyle(
        TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: white, height: 1.3),
        hSpacing, blockSpacing, noSpacing, null,
      ),
      paragraph: DefaultTextBlockStyle(
        TextStyle(fontSize: 15, color: white, height: 1.5),
        hSpacing, noSpacing, noSpacing, null,
      ),
      bold: const TextStyle(fontWeight: FontWeight.w700),
      italic: const TextStyle(fontStyle: FontStyle.italic),
      underline: const TextStyle(decoration: TextDecoration.underline),
      strikeThrough: const TextStyle(decoration: TextDecoration.lineThrough),
      link: TextStyle(
        color: Colors.lightBlueAccent,
        decoration: TextDecoration.underline,
      ),
      placeHolder: DefaultTextBlockStyle(
        TextStyle(fontSize: 15, color: soft, height: 1.5),
        hSpacing, noSpacing, noSpacing, null,
      ),
      code: DefaultTextBlockStyle(
        TextStyle(fontSize: 13, color: white, fontFamily: 'monospace', height: 1.4),
        hSpacing, blockSpacing, noSpacing,
        BoxDecoration(
          color: AppColors.bg3.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      quote: DefaultTextBlockStyle(
        TextStyle(fontSize: 15, color: soft, fontStyle: FontStyle.italic, height: 1.5),
        hSpacing, blockSpacing, noSpacing,
        BoxDecoration(
          border: Border(left: BorderSide(color: soft.withValues(alpha: 0.4), width: 3)),
        ),
      ),
      lists: DefaultListBlockStyle(
        TextStyle(fontSize: 15, color: white, height: 1.5),
        hSpacing, blockSpacing, noSpacing, null, null,
      ),
      inlineCode: InlineCodeStyle(
        style: TextStyle(fontSize: 13, color: white, fontFamily: 'monospace'),
        backgroundColor: AppColors.bg3.withValues(alpha: 0.5),
      ),
    );
  }
}
