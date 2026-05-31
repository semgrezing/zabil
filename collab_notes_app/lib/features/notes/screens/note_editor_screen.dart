import 'dart:async';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:solar_icons/solar_icons.dart';
import '../providers/notes_provider.dart';
import '../models/note_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../shared/widgets/typing_indicator.dart';
import '../../../shared/widgets/note_presence_bar.dart';
import '../../../core/realtime/ws_client.dart';
import '../../../features/groups/providers/groups_provider.dart';
import 'image_viewer_screen.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  final String? noteId;

  const NoteEditorScreen({super.key, this.noteId});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _titleFocus = FocusNode();
  final _contentFocus = FocusNode();
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
    _contentCtrl.dispose();
    _titleFocus.dispose();
    _contentFocus.dispose();
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
        body: Center(child: Text('Ошибка: $err')),
      ),
      data: (note) => _buildEditor(note),
    );
  }

  Widget _buildEditor(NoteModel note) {
    _hydrateControllersFromNote(note);

    return PopScope(
      canPop: !_isDirty && !_isSaving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // User tried to go back while dirty or saving — save first, then pop.
        if (_isDirty) {
          _debounce?.cancel();
          await _saveNote(note.id);
        }
        if (!_isSaving && context.mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: _buildSaveStatus(),
          actions: [
            if (!note.isPersonal)
              IconButton(
                icon: const Icon(SolarIconsOutline.chatRound),
                tooltip: 'Чат заметки',
                onPressed: () => context.push(
                  '/chats/note/${note.id}?groupId=${note.groupId}&title=${Uri.encodeComponent(note.title)}&groupTitle=${Uri.encodeComponent(note.groupTitle ?? 'Группа')}',
                ),
              ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'move') {
                  _moveNote(note);
                }
                if (value == 'color') {
                  _pickColor(note);
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
            // Presence bar (#2) + Typing indicator (#6)
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

            // Content
            TextField(
              controller: _contentCtrl,
              focusNode: _contentFocus,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                hintText: 'Начните писать...',
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
                              .read(noteEditorProvider(note.id).notifier)
                              .deleteImage(image.id);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Не удалось удалить: $e')),
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bg2.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _EditorBarAction(
                    icon: SolarIconsOutline.checkCircle,
                    label: 'Пункт',
                    enabled: !_isSaving,
                    onTap: () => _onChecklistActionTap(note),
                  ),
                  _EditorBarAction(
                    icon: Icons.short_text_rounded,
                    label: 'Текст',
                    enabled: !_isSaving,
                    onTap: () => _insertTextBlock(note.id),
                  ),
                  _EditorBarAction(
                    icon: SolarIconsOutline.gallery,
                    label: 'Изображение',
                    enabled: !_uploadingImages,
                    onTap: () => _pickAndUploadImages(note.id),
                  ),
                ],
              ),
            ),
          ),
        ),
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
      widgets.add(
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: () => _addItemToSection(note, section),
            icon: const Icon(SolarIconsOutline.addCircle),
            tooltip: 'Добавить пункт',
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
    return _isDirty || _titleFocus.hasFocus || _contentFocus.hasFocus;
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
      final content = _contentCtrl.text;
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
          SnackBar(content: Text('Не удалось сохранить: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _hydrateControllersFromNote(NoteModel note) {
    final hasLocalInput = _isDirty || _titleFocus.hasFocus || _contentFocus.hasFocus;
    if (hasLocalInput) return;

    final isFirstHydration = _lastHydratedNoteId != note.id;
    final isNewerFromServer = _lastHydratedUpdatedAt == null ||
        note.updatedAt.isAfter(_lastHydratedUpdatedAt!);

    if (!isFirstHydration && !isNewerFromServer) return;

    _titleCtrl.value = TextEditingValue(
      text: note.title,
      selection: TextSelection.collapsed(offset: note.title.length),
    );
    _contentCtrl.value = TextEditingValue(
      text: note.content,
      selection: TextSelection.collapsed(offset: note.content.length),
    );

    _lastHydratedNoteId = note.id;
    _lastHydratedUpdatedAt = note.updatedAt;
  }

  Future<void> _reorderChecklistAdjusted(NoteModel note, int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;

    final items = List<ChecklistItem>.from(note.checklistItems);
    final movedItem = items.removeAt(oldIndex);
    items.insert(newIndex, movedItem);

    // Optimistically update local state
    ref.read(noteDetailProvider(note.id).notifier).reorderChecklistLocally(items);

    // Persist new positions to backend
    final service = ref.read(notesServiceProvider);
    for (int i = 0; i < items.length; i++) {
      if (items[i].position != i) {
        await service.updateChecklistItem(note.id, items[i].id, position: i);
      }
    }
  }

  Future<void> _onChecklistActionTap(NoteModel note) async {
    final text = await _showChecklistInputDialog();
    if (text == null || text.trim().isEmpty) return;

    final createNewSection = _startNewChecklistOnNextAdd && note.checklistItems.isNotEmpty;
    final sectionId = createNewSection
        ? _generateChecklistSectionId()
        : (note.checklistItems.isNotEmpty
            ? note.checklistItems.last.sectionId
            : 'main');

    await _addChecklistItem(note.id, text.trim(), sectionId: sectionId);

    if (mounted && createNewSection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Создан новый чеклист')),
      );
    }

    setState(() => _startNewChecklistOnNextAdd = false);
  }

  Future<void> _addItemToSection(NoteModel note, _ChecklistSection section) async {
    final text = await _showChecklistInputDialog();
    if (text == null || text.trim().isEmpty) return;
    await _addChecklistItem(
      note.id,
      text.trim(),
      position: section.endExclusive,
      sectionId: section.sectionId,
    );
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

  void _insertTextBlock(String noteId) {
    final value = _contentCtrl.value;
    final start = value.selection.start >= 0 ? value.selection.start : value.text.length;
    final end = value.selection.end >= 0 ? value.selection.end : value.text.length;
    const insertion = '\n\n';
    final nextText = value.text.replaceRange(start, end, insertion);
    final caret = start + insertion.length;

    _contentCtrl.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: caret),
    );
    _contentFocus.requestFocus();
    setState(() => _startNewChecklistOnNextAdd = true);
    _onEdited(noteId);
    _emitTyping(noteId);
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
        SnackBar(content: Text('Не удалось перенести заметку: $e')),
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
        SnackBar(content: Text('Не удалось обновить цвет: $e')),
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
  final _contentCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
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
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _contentCtrl,
                maxLines: null,
                expands: true,
                keyboardType: TextInputType.multiline,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Начните писать...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  filled: false,
                ),
              ),
            ),
          ],
        ),
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
      final note = await ref.read(notesProvider.notifier).createNote(
            groupId: groupId,
        personal: personal,
            title: _titleCtrl.text.trim(),
            content: _contentCtrl.text,
          );
      if (context.mounted) {
        context.go('/notes/${note.id}');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
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
      child: Row(
        children: [
          AnimatedBuilder(
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
          Expanded(
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
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: widget.onDelete,
            visualDensity: VisualDensity.compact,
          ),
        ],
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

