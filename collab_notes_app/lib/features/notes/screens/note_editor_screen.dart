import 'dart:async';
import 'dart:convert';
import '../../../shared/widgets/frosted_bar.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:solar_icons/solar_icons.dart';
import '../providers/notes_provider.dart';
import '../providers/block_editor_provider.dart';
import '../models/note_model.dart';
import '../models/note_block_model.dart';
import '../widgets/blocks/block_row.dart';
import '../widgets/blocks/insert_block_button.dart';
import '../widgets/blocks/slash_command_overlay.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../shared/widgets/typing_indicator.dart';
import '../../../shared/widgets/note_presence_bar.dart';
import '../../../core/realtime/ws_client.dart';
import '../../../features/groups/providers/groups_provider.dart';
import 'image_viewer_screen.dart';
import '../../../core/utils/error_mapper.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class NoteEditorScreen extends ConsumerStatefulWidget {
  final String? noteId;

  const NoteEditorScreen({super.key, this.noteId});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final _titleCtrl = TextEditingController();
  final _titleFocus = FocusNode();
  QuillController? _quillController;
  final _editorFocusNode = FocusNode();
  final _editorScrollCtrl = ScrollController();
  bool _isDirty = false;
  bool _isSaving = false;
  bool _hasSavedOnce = false;
  Timer? _debounce;
  DateTime? _lastHydratedUpdatedAt;
  String? _lastHydratedNoteId;
  NoteModel? _pendingRemoteNote;
  bool _showRemoteBanner = false;
  Timer? _remotePoll;
  bool _uploadingImages = false;
  bool _showFormattingToolbar = false;

  // Presence & typing
  StreamSubscription? _wsSub;
  WsClient? _wsClient;
  final List<NoteViewer> _viewers = [];
  String? _currentUserId;
  String? _currentUserDisplayName;
  String? _typingUserId;
  Timer? _typingTimer;
  Timer? _typingDebounce;
  bool _startNewChecklistOnNextAdd = false;

  // Inline checklist input controllers/focus nodes per section
  final Map<String, TextEditingController> _inlineChecklistCtrls = {};
  final Map<String, FocusNode> _inlineChecklistFocusNodes = {};

  bool get _isNew => widget.noteId == null;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateProvider).valueOrNull?.user;
    _currentUserId = user?.id;
    _currentUserDisplayName = user?.displayLabel;
    if (!_isNew) {
      _setupPresence();
      _startRemotePolling();
    }
  }

  void _setupPresence() {
    final selfId = _currentUserId;
    final selfName = _currentUserDisplayName;
    if (selfId != null && selfName != null) {
      _viewers.add(NoteViewer(userId: selfId, displayName: selfName));
      _sortViewers();
    }

    final ws = ref.read(wsClientProvider);
    _wsClient = ws;
    ws.sendPresence(widget.noteId!, 'join');
    _wsSub = ws.events.listen((event) {
      if (event is NotePresenceEvent && event.noteId == widget.noteId) {
        setState(() {
          if (event.action == 'join') {
            if (!_viewers.any((v) => v.userId == event.userId)) {
              _viewers.add(NoteViewer(
                userId: event.userId,
                displayName: event.displayName,
              ));
            }
          } else {
            _viewers.removeWhere((v) => v.userId == event.userId);
          }
          _sortViewers();
        });
      } else if (event is NoteTypingEvent && event.noteId == widget.noteId) {
        setState(() => _typingUserId = event.userId);
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _typingUserId = null);
        });
      }
    });
  }

  void _sortViewers() {
    _viewers.sort((a, b) {
      final aSelf = a.userId == _currentUserId;
      final bSelf = b.userId == _currentUserId;
      if (aSelf && !bSelf) return -1;
      if (!aSelf && bSelf) return 1;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
  }

  void _startRemotePolling() {
    _remotePoll?.cancel();
    _remotePoll = Timer.periodic(const Duration(seconds: 5), (_) {
      final id = widget.noteId;
      if (id == null || !mounted) return;
      _checkForRemoteUpdates(id, fromPullToRefresh: false);
    });
  }

  void _emitTyping(String noteId) {
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(wsClientProvider).sendTyping(noteId);
    });
  }

  @override
  void dispose() {
    if (!_isNew) {
      _wsClient?.sendPresence(widget.noteId!, 'leave');
    }
    _wsSub?.cancel();
    _typingTimer?.cancel();
    _typingDebounce?.cancel();
    _remotePoll?.cancel();
    _debounce?.cancel();
    _titleCtrl.dispose();
    _quillController?.dispose();
    _editorFocusNode.dispose();
    _editorScrollCtrl.dispose();
    _titleFocus.dispose();
    for (final ctrl in _inlineChecklistCtrls.values) {
      ctrl.dispose();
    }
    for (final node in _inlineChecklistFocusNodes.values) {
      node.dispose();
    }
    for (final node in _blockFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isNew) {
      return _NewNoteEditor(ref: ref);
    }

    final noteAsync = ref.watch(noteDetailProvider(widget.noteId!));

    return noteAsync.when(
      loading: () => const Scaffold(body: AppLoader()),
      error: (err, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(mapError(err))),
      ),
      data: (note) => _buildEditor(note),
    );
  }

  Widget _buildEditor(NoteModel note) {
    if (note.migrated) return _buildBlockEditor(note);
    _hydrateControllersFromNote(note);

    final bgTint = note.colorLabel != null
        ? Color(int.parse(note.colorLabel!.replaceFirst('#', '0xFF')))
            .withValues(alpha: 0.08)
        : null;

    return PopScope(
      canPop: !_isDirty && !_isSaving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_isDirty) {
          _debounce?.cancel();
          await _saveNote(note.id);
        }
        if (!_isSaving && context.mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: bgTint != null
            ? Color.alphaBlend(bgTint, AppColors.bg1)
            : null,
        appBar: AppBar(
          title: _buildSaveStatus(),
          actions: [
            IconButton(
              icon: const Icon(SolarIconsOutline.calendar),
              tooltip: 'В календарь',
              onPressed: () => _showCalendarSheet(note),
            ),
            if (!note.isPersonal)
              IconButton(
                icon: const Icon(SolarIconsOutline.chatRound),
                tooltip: 'Чат заметки',
                onPressed: () => context.push(
                  '/chats/note/${note.id}?groupId=${note.groupId}&title=${Uri.encodeComponent(note.title)}&groupTitle=${Uri.encodeComponent(note.groupTitle ?? 'Группа')}',
                ),
              ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'move') {
                  await _moveNote(note);
                } else if (value == 'color') {
                  await _pickColor(note);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'move',
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz),
                      SizedBox(width: 8),
                      Text('Переместить'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'color',
                  child: Row(
                    children: [
                      Icon(Icons.palette_outlined),
                      SizedBox(width: 8),
                      Text('Цветовая метка'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () => _checkForRemoteUpdates(note.id, fromPullToRefresh: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 132),
                children: [
            if (_showRemoteBanner && _pendingRemoteNote != null)
              _buildRemoteUpdateBanner(note.id),
            if (_viewers.isNotEmpty || _typingUserId != null) ...[
              if (_viewers.isNotEmpty)
                NotePresenceBar(viewers: _viewers),
              if (_typingUserId != null)
                const Padding(
                  padding: EdgeInsets.only(top: 4, bottom: 4),
                  child: Row(
                    children: [
                      TypingIndicator(),
                      SizedBox(width: 6),
                      Text(
                        'печатает...',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.fgSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
            ],

            // Title
            TextField(
              controller: _titleCtrl,
              focusNode: _titleFocus,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              decoration: const InputDecoration(
                hintText: 'Заголовок',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                filled: false,
              ),
              onChanged: (_) {
                _onEdited(note.id);
                _emitTyping(note.id);
              },
            ),
            if (note.colorLabel != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Color(int.parse(note.colorLabel!.replaceFirst('#', '0xFF'))),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Цветовая метка',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),

            // Rich text editor
            if (_quillController != null)
              QuillEditor.basic(
                controller: _quillController!,
                focusNode: _editorFocusNode,
                scrollController: _editorScrollCtrl,
                config: QuillEditorConfig(
                  placeholder: 'Начните писать...',
                  padding: EdgeInsets.zero,
                  autoFocus: false,
                  expands: false,
                  scrollable: false,
                  customStyles: _buildQuillDarkStyles(context),
                ),
              ),
            const Divider(height: 32),

            // Checklist sections
            ..._buildChecklistSections(note),
            if (note.checklistItems.isNotEmpty) const SizedBox(height: 8),

            // Images
            if (note.images.isNotEmpty) ...[
              Text('Изображения', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: note.images.length,
                itemBuilder: (context, index) {
                  final image = note.images[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ImageViewerScreen(
                            noteId: note.id,
                            images: note.images,
                            initialIndex: index,
                          ),
                        ),
                      );
                    },
                    onLongPress: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Удалить изображение?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Отмена'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Удалить'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && context.mounted) {
                        try {
                          await ref
                              .read(noteDetailProvider(note.id).notifier)
                              .deleteImage(image.id);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Не удалось удалить: ${mapError(e)}')),
                            );
                          }
                        }
                      }
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        image.url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],

            if (_uploadingImages)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
              ),
            ),
            _buildFloatingBar(note),
          ],
        ),
      ),
    );
  }

  // ── Block-based editor ──────────────────────────────────────────────────

  final Map<String, FocusNode> _blockFocusNodes = {};

  FocusNode _focusNodeForBlock(String blockId) {
    return _blockFocusNodes.putIfAbsent(blockId, () {
      final node = FocusNode();
      node.addListener(() {
        if (node.hasFocus) {
          ref.read(focusedBlockIdProvider.notifier).state = blockId;
        }
      });
      return node;
    });
  }

  Widget _buildBlockEditor(NoteModel note) {
    _hydrateTitleFromNote(note);

    final blocksAsync = ref.watch(blockEditorProvider(note.id));
    final focusedId = ref.watch(focusedBlockIdProvider);

    final bgTint = note.colorLabel != null
        ? Color(int.parse(note.colorLabel!.replaceFirst('#', '0xFF')))
            .withValues(alpha: 0.08)
        : null;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) return;
        final title = _titleCtrl.text.trim();
        if (title.isNotEmpty && title != note.title) {
          await ref.read(notesProvider.notifier).updateNote(note.id, title: title);
        }
        await ref.read(blockEditorProvider(note.id).notifier).flushAll();
      },
      child: Scaffold(
        backgroundColor: bgTint != null
            ? Color.alphaBlend(bgTint, AppColors.bg1)
            : null,
        appBar: AppBar(
          title: _buildSaveStatus(),
          actions: [
            IconButton(
              icon: const Icon(SolarIconsOutline.calendar),
              tooltip: 'В календарь',
              onPressed: () => _showCalendarSheet(note),
            ),
            if (!note.isPersonal)
              IconButton(
                icon: const Icon(SolarIconsOutline.chatRound),
                tooltip: 'Чат заметки',
                onPressed: () => context.push(
                  '/chats/note/${note.id}?groupId=${note.groupId}&title=${Uri.encodeComponent(note.title)}&groupTitle=${Uri.encodeComponent(note.groupTitle ?? 'Группа')}',
                ),
              ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'move') {
                  await _moveNote(note);
                } else if (value == 'color') {
                  await _pickColor(note);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'move',
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz),
                      SizedBox(width: 8),
                      Text('Переместить'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'color',
                  child: Row(
                    children: [
                      Icon(Icons.palette_outlined),
                      SizedBox(width: 8),
                      Text('Цветовая метка'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Stack(
          children: [
            blocksAsync.when(
              loading: () => const AppLoader(),
              error: (err, _) => Center(child: Text(mapError(err))),
              data: (blocks) => _buildBlockList(note, blocks, focusedId),
            ),
            _buildBlockFloatingBar(note),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockList(NoteModel note, List<NoteBlockModel> blocks, String? focusedId) {
    final itemCount = blocks.length * 2 + 1;

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 132),
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        ref.read(blockEditorProvider(note.id).notifier).reorderBlocks(oldIndex, newIndex);
      },
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_showRemoteBanner && _pendingRemoteNote != null)
            _buildRemoteUpdateBanner(note.id),
          if (_viewers.isNotEmpty)
            NotePresenceBar(viewers: _viewers),
          if (_typingUserId != null)
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 4),
              child: Row(
                children: [
                  TypingIndicator(),
                  SizedBox(width: 6),
                  Text('печатает...', style: TextStyle(fontSize: 12, color: AppColors.fgSoft)),
                ],
              ),
            ),
          if (_viewers.isNotEmpty || _typingUserId != null)
            const SizedBox(height: 8),
          TextField(
            controller: _titleCtrl,
            focusNode: _titleFocus,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              hintText: 'Заголовок',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              filled: false,
            ),
            onChanged: (_) {
              _onEdited(note.id);
              _emitTyping(note.id);
            },
          ),
          if (note.colorLabel != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Color(int.parse(note.colorLabel!.replaceFirst('#', '0xFF'))),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text('Цветовая метка', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
          const SizedBox(height: 12),
          InsertBlockButton(
            onInsert: (type) => _insertBlockAt(note.id, type, 0),
          ),
        ],
      ),
      itemCount: blocks.length,
      itemBuilder: (context, index) {
        final block = blocks[index];
        return Column(
          key: ValueKey(block.id),
          mainAxisSize: MainAxisSize.min,
          children: [
            BlockRow(
              block: block,
              focusNode: _focusNodeForBlock(block.id),
              isFocused: focusedId == block.id,
              onContentChanged: (content) {
                ref.read(blockEditorProvider(note.id).notifier).markBlockDirty(block.id, content);
              },
              onDelete: () {
                ref.read(blockEditorProvider(note.id).notifier).deleteBlock(block.id);
              },
              onSlashTyped: () => _showSlashMenu(note.id, block),
              onImageTap: block.type == NoteBlockType.image && block.imageData != null
                  ? () {
                      final data = block.imageData!;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ImageViewerScreen(
                            noteId: note.id,
                            images: [NoteImage(
                              id: data.imageId,
                              noteId: note.id,
                              filename: data.filename,
                              path: data.path,
                            )],
                            initialIndex: 0,
                          ),
                        ),
                      );
                    }
                  : null,
            ),
            InsertBlockButton(
              onInsert: (type) => _insertBlockAt(note.id, type, index + 1),
            ),
          ],
        );
      },
    );
  }

  Future<void> _insertBlockAt(String noteId, NoteBlockType type, int position) async {
    if (type == NoteBlockType.image) {
      await _pickAndUploadImageBlock(noteId, position);
      return;
    }
    final block = await ref.read(blockEditorProvider(noteId).notifier).insertBlock(type, position);
    if (block != null && block.type == NoteBlockType.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNodeForBlock(block.id).requestFocus();
      });
    }
  }

  Future<void> _pickAndUploadImageBlock(String noteId, int position) async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(
      imageQuality: 65,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (images.isEmpty) return;

    final service = ref.read(notesServiceProvider);
    for (final img in images) {
      try {
        final uploaded = await service.uploadImage(noteId, img.path);
        final content = jsonEncode({
          'imageId': uploaded.id,
          'filename': uploaded.filename,
          'path': uploaded.path,
        });
        await ref.read(blockEditorProvider(noteId).notifier).insertBlock(
          NoteBlockType.image,
          position,
          content: content,
        );
        position++;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Не удалось загрузить: ${mapError(e)}')),
          );
        }
      }
    }
  }

  void _showSlashMenu(String noteId, NoteBlockModel block) {
    final blocks = ref.read(blockEditorProvider(noteId)).valueOrNull ?? [];
    final blockIndex = blocks.indexWhere((b) => b.id == block.id);
    if (blockIndex == -1) return;

    showModalBottomSheet<NoteBlockType>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16, left: 24, right: 24),
          child: SlashCommandMenu(
            onSelect: (type) => Navigator.pop(ctx, type),
          ),
        ),
      ),
    ).then((type) {
      if (type == null) return;
      // Remove the "/" from the text block
      final focusNode = _blockFocusNodes[block.id];
      // Insert block after current
      _insertBlockAt(noteId, type, blockIndex + 1);
    });
  }

  Widget _buildBlockFloatingBar(NoteModel note) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final bottomOffset = keyboard > 0 ? keyboard + 12 : media.padding.bottom + 8;

    return Positioned(
      left: 12,
      right: 12,
      bottom: 0,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomOffset),
        child: FrostedBar(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _EditorBarAction(
                    icon: SolarIconsOutline.textFieldFocus,
                    label: 'Текст',
                    enabled: true,
                    onTap: () {
                      final blocks = ref.read(blockEditorProvider(note.id)).valueOrNull ?? [];
                      final focusedId = ref.read(focusedBlockIdProvider);
                      final idx = blocks.indexWhere((b) => b.id == focusedId);
                      final pos = idx >= 0 ? idx + 1 : blocks.length;
                      _insertBlockAt(note.id, NoteBlockType.text, pos);
                    },
                  ),
                  _EditorBarAction(
                    icon: SolarIconsOutline.checkSquare,
                    label: 'Чеклист',
                    enabled: true,
                    onTap: () {
                      final blocks = ref.read(blockEditorProvider(note.id)).valueOrNull ?? [];
                      final focusedId = ref.read(focusedBlockIdProvider);
                      final idx = blocks.indexWhere((b) => b.id == focusedId);
                      final pos = idx >= 0 ? idx + 1 : blocks.length;
                      _insertBlockAt(note.id, NoteBlockType.checklist, pos);
                    },
                  ),
                  _EditorBarAction(
                    icon: SolarIconsOutline.gallery,
                    label: 'Фото',
                    enabled: true,
                    onTap: () {
                      final blocks = ref.read(blockEditorProvider(note.id)).valueOrNull ?? [];
                      final focusedId = ref.read(focusedBlockIdProvider);
                      final idx = blocks.indexWhere((b) => b.id == focusedId);
                      final pos = idx >= 0 ? idx + 1 : blocks.length;
                      _pickAndUploadImageBlock(note.id, pos);
                    },
                  ),
                  _EditorBarAction(
                    icon: SolarIconsOutline.minusCircle,
                    label: 'Линия',
                    enabled: true,
                    onTap: () {
                      final blocks = ref.read(blockEditorProvider(note.id)).valueOrNull ?? [];
                      final focusedId = ref.read(focusedBlockIdProvider);
                      final idx = blocks.indexWhere((b) => b.id == focusedId);
                      final pos = idx >= 0 ? idx + 1 : blocks.length;
                      _insertBlockAt(note.id, NoteBlockType.divider, pos);
                    },
                  ),
                  _EditorBarAction(
                    icon: Icons.text_format_rounded,
                    label: 'Формат',
                    enabled: true,
                    onTap: () => setState(() => _showFormattingToolbar = true),
                  ),
                ],
              ),
              if (_showFormattingToolbar)
                Positioned(
                  left: -12,
                  right: -12,
                  bottom: -12,
                  child: FrostedBar(child: _buildFormattingToolbar()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  DefaultStyles _buildQuillDarkStyles(BuildContext context) {
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
        TextStyle(
          fontSize: 13,
          color: white,
          fontFamily: 'monospace',
          height: 1.4,
        ),
        hSpacing,
        blockSpacing,
        noSpacing,
        BoxDecoration(
          color: AppColors.bg3.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      quote: DefaultTextBlockStyle(
        TextStyle(fontSize: 15, color: soft, fontStyle: FontStyle.italic, height: 1.5),
        hSpacing,
        blockSpacing,
        noSpacing,
        BoxDecoration(
          border: Border(
            left: BorderSide(color: soft.withValues(alpha: 0.4), width: 3),
          ),
        ),
      ),
      lists: DefaultListBlockStyle(
        TextStyle(fontSize: 15, color: white, height: 1.5),
        hSpacing, blockSpacing, noSpacing, null, null,
      ),
      inlineCode: InlineCodeStyle(
        style: TextStyle(
          fontSize: 13,
          color: white,
          fontFamily: 'monospace',
        ),
        backgroundColor: AppColors.bg3.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildFloatingBar(NoteModel note) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final bottomOffset = keyboard > 0 ? keyboard + 12 : media.padding.bottom + 8;

    return Positioned(
      left: 12,
      right: 12,
      bottom: 0,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomOffset),
        child: FrostedBar(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _buildActionBar(note),
              if (_showFormattingToolbar)
                Positioned(
                  left: -12,
                  right: -12,
                  bottom: -12,
                  child: FrostedBar(child: _buildFormattingToolbar()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionBar(NoteModel note) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _EditorBarAction(
          icon: SolarIconsOutline.checkCircle,
          label: 'Пункт',
          enabled: !_isSaving,
          onTap: () => _onChecklistActionTap(note),
        ),
        _EditorBarAction(
          icon: Icons.text_format_rounded,
          label: 'Формат',
          enabled: !_isSaving && _quillController != null,
          onTap: () => setState(() => _showFormattingToolbar = true),
        ),
        _EditorBarAction(
          icon: SolarIconsOutline.gallery,
          label: 'Фото',
          enabled: !_uploadingImages,
          onTap: () => _pickAndUploadImages(note.id),
        ),
      ],
    );
  }

  Widget _buildFormattingToolbar() {
    if (_quillController == null) return const SizedBox.shrink();

    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: _quillController!,
              builder: (context, _) {
                final style = _quillController!.getSelectionStyle();
                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  children: [
                    _FmtBtn(
                      icon: Icons.format_bold,
                      active: style.containsKey(Attribute.bold.key),
                      onTap: () => _toggleInlineAttr(Attribute.bold),
                    ),
                    _FmtBtn(
                      icon: Icons.format_italic,
                      active: style.containsKey(Attribute.italic.key),
                      onTap: () => _toggleInlineAttr(Attribute.italic),
                    ),
                    _FmtBtn(
                      icon: Icons.format_underline,
                      active: style.containsKey(Attribute.underline.key),
                      onTap: () => _toggleInlineAttr(Attribute.underline),
                    ),
                    _FmtBtn(
                      icon: Icons.format_strikethrough,
                      active: style.containsKey(Attribute.strikeThrough.key),
                      onTap: () => _toggleInlineAttr(Attribute.strikeThrough),
                    ),
                    _fmtDivider(),
                    _FmtBtn(
                      icon: Icons.format_list_bulleted,
                      active: style.containsKey(Attribute.ul.key),
                      onTap: () => _toggleBlockAttr(Attribute.ul),
                    ),
                    _FmtBtn(
                      icon: Icons.format_list_numbered,
                      active: style.containsKey(Attribute.ol.key),
                      onTap: () => _toggleBlockAttr(Attribute.ol),
                    ),
                    _FmtBtn(
                      icon: Icons.checklist,
                      active: style.containsKey(Attribute.unchecked.key),
                      onTap: () => _toggleBlockAttr(Attribute.unchecked),
                    ),
                    _fmtDivider(),
                    _FmtBtn(
                      icon: Icons.format_quote,
                      active: style.containsKey(Attribute.blockQuote.key),
                      onTap: () => _toggleBlockAttr(Attribute.blockQuote),
                    ),
                    _FmtBtn(
                      icon: Icons.code,
                      active: style.containsKey(Attribute.inlineCode.key),
                      onTap: () => _toggleInlineAttr(Attribute.inlineCode),
                    ),
                    _FmtBtn(
                      icon: Icons.data_object,
                      active: style.containsKey(Attribute.codeBlock.key),
                      onTap: () => _toggleBlockAttr(Attribute.codeBlock),
                    ),
                    _FmtBtn(
                      icon: Icons.format_clear,
                      active: false,
                      onTap: _clearFormat,
                    ),
                  ],
                );
              },
            ),
          ),
          Container(
            width: 1,
            height: 24,
            color: AppColors.fgSoft.withValues(alpha: 0.2),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.fgSoft),
            onPressed: () => setState(() => _showFormattingToolbar = false),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  void _toggleInlineAttr(Attribute attr) {
    final style = _quillController!.getSelectionStyle();
    final isSet = style.containsKey(attr.key);
    _quillController!.formatSelection(isSet ? Attribute.clone(attr, null) : attr);
  }

  void _toggleBlockAttr(Attribute attr) {
    final style = _quillController!.getSelectionStyle();
    final isSet = style.containsKey(attr.key);
    _quillController!.formatSelection(isSet ? Attribute.clone(attr, null) : attr);
  }

  void _clearFormat() {
    final range = _quillController!.selection;
    if (range.isCollapsed) return;
    for (final attr in [
      Attribute.bold,
      Attribute.italic,
      Attribute.underline,
      Attribute.strikeThrough,
      Attribute.inlineCode,
    ]) {
      _quillController!.formatSelection(Attribute.clone(attr, null));
    }
  }

  Widget _fmtDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
      child: Container(
        width: 1,
        color: AppColors.fgSoft.withValues(alpha: 0.2),
      ),
    );
  }

  List<Widget> _buildChecklistSections(NoteModel note) {
    if (note.checklistItems.isEmpty) return const [];

    final sections = _splitChecklistSections(note.checklistItems);
    final widgets = <Widget>[];

    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      widgets.add(
        Text(
          sections.length == 1 ? 'Чеклист' : 'Чеклист ${i + 1}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
      );
      widgets.add(const SizedBox(height: 8));
      widgets.add(
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: section.items.length,
          onReorderItem: (oldIndex, newIndex) {
            final oldGlobal = section.start + oldIndex;
            final newGlobal = section.start + newIndex;
            _reorderChecklistAdjusted(note, oldGlobal, newGlobal);
          },
          itemBuilder: (context, index) {
            final item = section.items[index];
            return _ChecklistItemTile(
              key: ValueKey(item.id),
              item: item,
              noteId: note.id,
              index: index,
              onToggle: (completed) {
                ref
                    .read(noteDetailProvider(note.id).notifier)
                    .toggleChecklistItem(item.id, completed);
              },
              onDelete: () => ref
                  .read(noteDetailProvider(note.id).notifier)
                  .deleteChecklistItem(item.id),
              onRename: (text) => ref
                  .read(noteDetailProvider(note.id).notifier)
                  .updateChecklistItemText(item.id, text),
            );
          },
        ),
      );
      final sectionKey = section.sectionId;
      _inlineChecklistCtrls[sectionKey] ??= TextEditingController();
      _inlineChecklistFocusNodes[sectionKey] ??= FocusNode();
      final inlineCtrl = _inlineChecklistCtrls[sectionKey]!;
      final inlineFocus = _inlineChecklistFocusNodes[sectionKey]!;

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            children: [
              const SizedBox(width: 40),
              Expanded(
                child: TextField(
                  controller: inlineCtrl,
                  focusNode: inlineFocus,
                  decoration: const InputDecoration(
                    hintText: 'Новый пункт...',
                    hintStyle: TextStyle(color: AppColors.fgSoft, fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  style: const TextStyle(fontSize: 14),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (text) async {
                    if (text.trim().isEmpty) return;
                    await _addChecklistItem(
                      note.id,
                      text.trim(),
                      position: section.endExclusive,
                      sectionId: section.sectionId,
                    );
                    inlineCtrl.clear();
                    inlineFocus.requestFocus();
                  },
                ),
              ),
            ],
          ),
        ),
      );
      widgets.add(const SizedBox(height: 8));
    }

    return widgets;
  }

  List<_ChecklistSection> _splitChecklistSections(List<ChecklistItem> source) {
    final items = [...source]..sort((a, b) => a.position.compareTo(b.position));
    final sections = <_ChecklistSection>[];
    var current = <ChecklistItem>[];
    var currentSectionId = 'main';
    var sectionStart = 0;

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final itemSectionId = item.sectionId.trim().isEmpty ? 'main' : item.sectionId;
      if (current.isNotEmpty && itemSectionId != currentSectionId) {
        sections.add(
          _ChecklistSection(
            start: sectionStart,
            sectionId: currentSectionId,
            items: current,
          ),
        );
        current = <ChecklistItem>[item];
        currentSectionId = itemSectionId;
        sectionStart = i;
      } else {
        if (current.isEmpty) currentSectionId = itemSectionId;
        current.add(item);
      }
    }

    if (current.isNotEmpty) {
      sections.add(
        _ChecklistSection(
          start: sectionStart,
          sectionId: currentSectionId,
          items: current,
        ),
      );
    }
    return sections;
  }

  Widget _buildRemoteUpdateBanner(String noteId) {
    final pending = _pendingRemoteNote;
    if (pending == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const Icon(SolarIconsOutline.bell, size: 16, color: AppColors.fgSoft),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Есть новые изменения в заметке',
              style: TextStyle(fontSize: 13, color: AppColors.fgSoft),
            ),
          ),
          TextButton(
            onPressed: () => _resolveRemoteConflict(noteId, pending),
            child: const Text('Открыть'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _showRemoteBanner = false);
            },
            child: const Text('Позже'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkForRemoteUpdates(
    String noteId, {
    required bool fromPullToRefresh,
  }) async {
    if (!mounted || _isSaving) return;

    final current = ref.read(noteDetailProvider(noteId)).valueOrNull;
    if (current == null) return;

    try {
      final latest = await ref.read(notesServiceProvider).getNoteById(noteId);
      final isNewer = latest.updatedAt.isAfter(current.updatedAt);
      if (!isNewer) {
        if (fromPullToRefresh && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Изменений не найдено')),
          );
        }
        return;
      }

      if (_hasLocalInput()) {
        if (!mounted) return;
        setState(() {
          _pendingRemoteNote = latest;
          _showRemoteBanner = true;
        });
        if (fromPullToRefresh) {
          await _resolveRemoteConflict(noteId, latest);
        }
        return;
      }

      ref.read(noteDetailProvider(noteId).notifier).applyRemoteSnapshot(latest);
      if (!mounted) return;
      setState(() {
        _pendingRemoteNote = null;
        _showRemoteBanner = false;
      });
      if (fromPullToRefresh) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заметка обновлена')),
        );
      }
    } catch (_) {
      if (fromPullToRefresh && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось обновить заметку')),
        );
      }
    }
  }

  bool _hasLocalInput() {
    return _isDirty || _titleFocus.hasFocus || _editorFocusNode.hasFocus;
  }

  Future<void> _resolveRemoteConflict(String noteId, NoteModel latest) async {
    if (!mounted) return;

    final apply = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Найдены новые изменения'),
        content: const Text(
          'В заметке появились изменения на сервере. Применить их сейчас? Локальный несохраненный ввод будет заменен.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Оставить мое'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Применить'),
          ),
        ],
      ),
    );

    if (apply != true || !mounted) return;
    ref.read(noteDetailProvider(noteId).notifier).applyRemoteSnapshot(latest);
    setState(() {
      _isDirty = false;
      _pendingRemoteNote = null;
      _showRemoteBanner = false;
      _lastHydratedNoteId = null;
    });
  }

  void _onEdited(String noteId) {
    setState(() => _isDirty = true);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1500), () {
      _saveNote(noteId);
    });
  }

  Widget _buildSaveStatus() {
    if (_isSaving) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text(
            'Сохранение...',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.fgSoft,
            ),
          ),
        ],
      );
    }
    if (_hasSavedOnce && !_isDirty) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(SolarIconsOutline.checkCircle, size: 14, color: AppColors.fgSoft),
          SizedBox(width: 6),
          Text(
            'Сохранено',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.fgSoft,
            ),
          ),
        ],
      );
    }
    return const Text('Заметка');
  }

  Future<void> _saveNote(String noteId) async {
    if (_isSaving) return;
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final content = _quillController != null
          ? jsonEncode(_quillController!.document.toDelta().toJson())
          : '';
      await ref.read(notesProvider.notifier).updateNote(
            noteId,
            title: title,
            content: content,
          );
      ref.read(noteDetailProvider(noteId).notifier).applyLocalTextEdits(
            title: title,
            content: content,
          );
      if (mounted) {
        setState(() {
          _isDirty = false;
          _hasSavedOnce = true;
          _lastHydratedNoteId = noteId;
          _lastHydratedUpdatedAt = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось сохранить: ${mapError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _hydrateTitleFromNote(NoteModel note) {
    final hasLocalInput = _isDirty || _titleFocus.hasFocus;
    if (hasLocalInput) return;

    final isFirstHydration = _lastHydratedNoteId != note.id;
    final isNewerFromServer = _lastHydratedUpdatedAt == null ||
        note.updatedAt.isAfter(_lastHydratedUpdatedAt!);
    if (!isFirstHydration && !isNewerFromServer) return;

    _titleCtrl.value = TextEditingValue(
      text: note.title,
      selection: TextSelection.collapsed(offset: note.title.length),
    );
    _lastHydratedNoteId = note.id;
    _lastHydratedUpdatedAt = note.updatedAt;

    if (!_isDirty) {
      ref.read(blockEditorProvider(note.id).notifier).replaceAll(note.blocks);
    }
  }

  void _hydrateControllersFromNote(NoteModel note) {
    final hasLocalInput = _isDirty || _titleFocus.hasFocus || _editorFocusNode.hasFocus;
    if (hasLocalInput) return;

    final isFirstHydration = _lastHydratedNoteId != note.id;
    final isNewerFromServer = _lastHydratedUpdatedAt == null ||
        note.updatedAt.isAfter(_lastHydratedUpdatedAt!);

    if (!isFirstHydration && !isNewerFromServer) return;

    _titleCtrl.value = TextEditingValue(
      text: note.title,
      selection: TextSelection.collapsed(offset: note.title.length),
    );

    final doc = note.contentDocument;
    if (_quillController == null) {
      _quillController = QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
      _quillController!.addListener(() {
        if (widget.noteId != null) {
          _onEdited(widget.noteId!);
          _emitTyping(widget.noteId!);
        }
      });
    } else {
      _quillController!.document = doc;
      _quillController!.moveCursorToStart();
    }

    _lastHydratedNoteId = note.id;
    _lastHydratedUpdatedAt = note.updatedAt;
  }

  Future<void> _reorderChecklistAdjusted(NoteModel note, int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;

    final items = List<ChecklistItem>.from(note.checklistItems);
    final movedItem = items.removeAt(oldIndex);
    items.insert(newIndex, movedItem);

    ref.read(noteDetailProvider(note.id).notifier).reorderChecklistLocally(items);

    final service = ref.read(notesServiceProvider);
    for (int i = 0; i < items.length; i++) {
      if (items[i].position != i) {
        await service.updateChecklistItem(note.id, items[i].id, position: i);
      }
    }
  }

  Future<void> _onChecklistActionTap(NoteModel note) async {
    if (note.checklistItems.isEmpty) {
      final text = await _showChecklistInputDialog();
      if (text == null || text.trim().isEmpty) return;
      await _addChecklistItem(note.id, text.trim(), sectionId: 'main');
      setState(() => _startNewChecklistOnNextAdd = false);
      return;
    }

    if (_startNewChecklistOnNextAdd) {
      final newSectionId = _generateChecklistSectionId();
      final text = await _showChecklistInputDialog();
      if (text == null || text.trim().isEmpty) return;
      await _addChecklistItem(note.id, text.trim(), sectionId: newSectionId);
      setState(() => _startNewChecklistOnNextAdd = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _inlineChecklistFocusNodes[newSectionId]?.requestFocus();
      });
      return;
    }

    final sections = _splitChecklistSections(note.checklistItems);
    if (sections.isNotEmpty) {
      final lastSectionId = sections.last.sectionId;
      final focusNode = _inlineChecklistFocusNodes[lastSectionId];
      if (focusNode != null) {
        focusNode.requestFocus();
      }
    }
  }

  String _generateChecklistSectionId() {
    return 'sec_${DateTime.now().microsecondsSinceEpoch}';
  }

  Future<String?> _showChecklistInputDialog() async {
    final ctrl = TextEditingController();
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useRootNavigator: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Текст пункта',
                ),
                onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
                  child: const Text('Добавить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    ctrl.dispose();
    return result;
  }

  Future<void> _addChecklistItem(
    String noteId,
    String text, {
    int? position,
    String? sectionId,
  }) async {
    if (text.trim().isEmpty) return;
    await ref
        .read(noteDetailProvider(noteId).notifier)
        .addChecklistItem(
          text.trim(),
          position: position,
          sectionId: sectionId,
        );
  }

  Future<void> _pickAndUploadImages(String noteId) async {
    final compressed = await _pickImageUploadMode();
    if (compressed == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(
      imageQuality: compressed ? 65 : null,
    );
    if (picked.isEmpty) return;

    final selected = picked.length > 10 ? picked.sublist(0, 10) : picked;
    if (picked.length > 10 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Можно загрузить до 10 изображений за раз')),
      );
    }

    setState(() => _uploadingImages = true);
    var uploaded = 0;
    var failed = 0;

    for (final image in selected) {
      try {
        await ref.read(noteDetailProvider(noteId).notifier).uploadImage(image.path);
        uploaded++;
      } catch (_) {
        failed++;
      }
    }

    if (!mounted) return;
    setState(() => _uploadingImages = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? 'Загружено изображений: $uploaded'
              : 'Загружено: $uploaded, ошибок: $failed',
        ),
      ),
    );
  }

  Future<bool?> _pickImageUploadMode() {
    return showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useRootNavigator: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Загрузка изображений',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.compress_outlined),
              title: const Text('Со сжатием'),
              subtitle: const Text('Меньше размер, быстрее загрузка'),
              onTap: () => Navigator.of(ctx).pop(true),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Без сжатия'),
              subtitle: const Text('Оригинальное качество'),
              onTap: () => Navigator.of(ctx).pop(false),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _showCalendarSheet(NoteModel note) async {
    DateTime selectedDate = DateTime.now();
    TimeOfDay? selectedTime;

    final result = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16, 8, 16, MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Добавить в календарь',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(SolarIconsOutline.calendar),
                  title: Text(DateFormat('d MMMM yyyy', 'ru').format(selectedDate)),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setSheetState(() => selectedDate = picked);
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(SolarIconsOutline.clockCircle),
                  title: Text(selectedTime != null
                      ? selectedTime!.format(ctx)
                      : 'Весь день'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selectedTime != null)
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setSheetState(() => selectedTime = null),
                        ),
                      const Icon(Icons.edit_outlined, size: 18),
                    ],
                  ),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime: selectedTime ?? TimeOfDay.now(),
                    );
                    if (picked != null) {
                      setSheetState(() => selectedTime = picked);
                    }
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Добавить'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result != true || !mounted) return;

    try {
      final ics = _buildIcs(
        title: note.title,
        description: NoteModel.extractPlainText(note.content),
        date: selectedDate,
        time: selectedTime,
      );

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/event.ics');
      await file.writeAsString(ics);

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: 'text/calendar')]),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${mapError(e)}')),
        );
      }
    }
  }

  String _buildIcs({
    required String title,
    required String description,
    required DateTime date,
    TimeOfDay? time,
  }) {
    final now = DateTime.now().toUtc();
    final stamp = _icsTimestamp(now);
    final uid = '${now.millisecondsSinceEpoch}@collab-notes';

    final buf = StringBuffer()
      ..writeln('BEGIN:VCALENDAR')
      ..writeln('VERSION:2.0')
      ..writeln('PRODID:-//CollabNotes//Event//RU')
      ..writeln('BEGIN:VEVENT')
      ..writeln('UID:$uid')
      ..writeln('DTSTAMP:$stamp')
      ..writeln('SUMMARY:${_icsEscape(title)}');

    if (time != null) {
      final start = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      final end = start.add(const Duration(hours: 1));
      buf
        ..writeln('DTSTART:${_icsTimestamp(start)}')
        ..writeln('DTEND:${_icsTimestamp(end)}');
    } else {
      final d = '${date.year}${_pad(date.month)}${_pad(date.day)}';
      buf
        ..writeln('DTSTART;VALUE=DATE:$d')
        ..writeln('DTEND;VALUE=DATE:$d');
    }

    if (description.isNotEmpty) {
      buf.writeln('DESCRIPTION:${_icsEscape(description)}');
    }

    buf
      ..writeln('END:VEVENT')
      ..writeln('END:VCALENDAR');
    return buf.toString();
  }

  String _icsTimestamp(DateTime dt) {
    final u = dt.toUtc();
    return '${u.year}${_pad(u.month)}${_pad(u.day)}T${_pad(u.hour)}${_pad(u.minute)}${_pad(u.second)}Z';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  String _icsEscape(String s) =>
      s.replaceAll('\\', '\\\\').replaceAll('\n', '\\n').replaceAll(',', '\\,').replaceAll(';', '\\;');

  Future<void> _moveNote(NoteModel note) async {
    final groups = ref.read(groupsProvider).valueOrNull ?? [];
    final personal = ref.read(personalContextProvider).valueOrNull;

    final contexts = <_MoveContextTarget>[
      if (personal != null && !note.isPersonal)
        _MoveContextTarget.personal(personal.id),
      ...groups
          .where((g) => g.id != note.groupId)
          .map((g) => _MoveContextTarget.group(g.id, g.title)),
    ];

    if (contexts.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет доступных групп для переноса')),
      );
      return;
    }

    final target = await showModalBottomSheet<_MoveContextTarget>(
      context: context,
      showDragHandle: true,
      useRootNavigator: true,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Переместить заметку',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
          ),
          ...contexts.map(
            (c) => ListTile(
              leading: Icon(
                c.personal ? SolarIconsOutline.user : SolarIconsOutline.usersGroupRounded,
              ),
              title: Text(c.title),
              onTap: () => Navigator.pop(ctx, c),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );

    if (target == null) return;

    try {
      await ref.read(notesProvider.notifier).moveNote(
            note.id,
            targetGroupId: target.personal ? null : target.id,
            targetPersonal: target.personal,
          );
      ref.invalidate(noteDetailProvider(note.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Заметка перемещена: ${target.title}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось перенести: ${mapError(e)}')),
      );
    }
  }

  Future<void> _pickColor(NoteModel note) async {
    const palette = [
      '#FF6B6B',
      '#F59F00',
      '#FFD43B',
      '#69DB7C',
      '#20C997',
      '#15AABF',
      '#4DABF7',
      '#748FFC',
      '#9775FA',
      '#DA77F2',
      '#F783AC',
      '#ADB5BD',
    ];

    final picked = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      useRootNavigator: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final hex in palette)
                GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(hex),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Color(int.parse(hex.replaceFirst('#', '0xFF'))),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: note.colorLabel == hex ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(ctx).pop(''),
                icon: const Icon(Icons.clear),
                label: const Text('Без метки'),
              ),
            ],
          ),
        ),
      ),
    );

    final normalized = (picked == null || picked.isEmpty) ? null : picked;
    if (normalized == note.colorLabel) return;

    try {
      await ref.read(notesProvider.notifier).updateNote(
            note.id,
            colorLabel: normalized,
          );
      ref.invalidate(noteDetailProvider(note.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось обновить цвет: ${mapError(e)}')),
      );
    }
  }
}

class _ChecklistSection {
  final int start;
  final String sectionId;
  final List<ChecklistItem> items;

  const _ChecklistSection({
    required this.start,
    required this.sectionId,
    required this.items,
  });

  int get endExclusive => start + items.length;
}

class _EditorBarAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _EditorBarAction({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.white : AppColors.fgSoft.withValues(alpha: 0.5);
    return Expanded(
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: SizedBox(
          height: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoveContextTarget {
  final String id;
  final String title;
  final bool personal;

  const _MoveContextTarget._({
    required this.id,
    required this.title,
    required this.personal,
  });

  factory _MoveContextTarget.personal(String id) =>
      _MoveContextTarget._(id: id, title: 'Личное', personal: true);

  factory _MoveContextTarget.group(String id, String title) =>
      _MoveContextTarget._(id: id, title: title, personal: false);
}

class _NewNoteEditor extends ConsumerStatefulWidget {
  final WidgetRef ref;

  const _NewNoteEditor({required this.ref});

  @override
  ConsumerState<_NewNoteEditor> createState() => _NewNoteEditorState();
}

class _NewNoteEditorState extends ConsumerState<_NewNoteEditor> {
  final _titleCtrl = TextEditingController();
  late final QuillController _quillController = QuillController.basic();
  bool _isSaving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _quillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queryParams = GoRouterState.of(context).uri.queryParameters;
    final groupId = queryParams['groupId'];
    final personal = queryParams['personal'] == 'true';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Новая заметка'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => _create(context, groupId, personal),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Создать'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: _titleCtrl,
              autofocus: true,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              decoration: const InputDecoration(
                hintText: 'Заголовок',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                filled: false,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: QuillEditor.basic(
                controller: _quillController,
                config: const QuillEditorConfig(
                  placeholder: 'Начните писать...',
                  padding: EdgeInsets.zero,
                  autoFocus: false,
                  expands: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _create(BuildContext context, String? groupId, bool personal) async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите заголовок')),
      );
      return;
    }
    if (!personal && groupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Группа не выбрана')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final content = jsonEncode(_quillController.document.toDelta().toJson());
      final note = await ref.read(notesProvider.notifier).createNote(
            groupId: groupId,
            personal: personal,
            title: _titleCtrl.text.trim(),
            content: content,
          );
      if (context.mounted) {
        context.go('/notes/${note.id}');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mapError(e))),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }
}

class _ChecklistItemTile extends StatefulWidget {
  final ChecklistItem item;
  final String noteId;
  final int index;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final Future<void> Function(String text) onRename;

  const _ChecklistItemTile({
    super.key,
    required this.item,
    required this.noteId,
    required this.index,
    required this.onToggle,
    required this.onDelete,
    required this.onRename,
  });

  @override
  State<_ChecklistItemTile> createState() => _ChecklistItemTileState();
}

class _ChecklistItemTileState extends State<_ChecklistItemTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late final Animation<double> _bounceAnim = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.9), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 30),
  ]).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeOut));
  late final TextEditingController _editCtrl =
      TextEditingController(text: widget.item.text);
  bool _editing = false;

  @override
  void didUpdateWidget(covariant _ChecklistItemTile old) {
    super.didUpdateWidget(old);
    if (!_editing && old.item.text != widget.item.text) {
      _editCtrl.text = widget.item.text;
    }
    if (old.item.completed != widget.item.completed && widget.item.completed) {
      _bounceCtrl.forward(from: 0);
      HapticFeedback.lightImpact();
    }
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    _editCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveEdit() async {
    final next = _editCtrl.text.trim();
    if (next.isEmpty || next == widget.item.text) {
      setState(() {
        _editing = false;
        _editCtrl.text = widget.item.text;
      });
      return;
    }
    await widget.onRename(next);
    if (!mounted) return;
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final tile = Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 36),
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: AnimatedBuilder(
              animation: _bounceAnim,
              builder: (context, child) => Transform.scale(
                scale: _bounceAnim.value,
                child: child,
              ),
              child: Checkbox(
                value: widget.item.completed,
                onChanged: (v) => widget.onToggle(v ?? false),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _editing
                  ? TextField(
                      controller: _editCtrl,
                      autofocus: true,
                      onSubmitted: (_) => _saveEdit(),
                      onEditingComplete: _saveEdit,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                      ),
                    )
                  : GestureDetector(
                      onDoubleTap: () {
                        setState(() {
                          _editing = true;
                          _editCtrl.text = widget.item.text;
                        });
                      },
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: widget.item.completed
                            ? TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                                fontSize: 14,
                              )
                            : TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 14,
                              ),
                        child: Text(widget.item.text),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: widget.onDelete,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
      ),
    );

    if (_editing) return tile;

    return _ChecklistLongPressDragStartListener(
      index: widget.index,
      child: tile,
    );
  }
}

class _ChecklistLongPressDragStartListener extends ReorderableDragStartListener {
  const _ChecklistLongPressDragStartListener({
    required super.index,
    required super.child,
  });

  @override
  MultiDragGestureRecognizer createRecognizer() {
    return DelayedMultiDragGestureRecognizer(
      delay: const Duration(milliseconds: 250),
      debugOwner: this,
    );
  }
}

class _FmtBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _FmtBtn({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: active ? AppColors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              icon,
              size: 18,
              color: active ? AppColors.bg1 : AppColors.white,
            ),
          ),
        ),
      ),
    );
  }
}
