import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:solar_icons/solar_icons.dart';
import '../providers/notes_provider.dart';
import '../models/note_model.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../shared/widgets/typing_indicator.dart';
import '../../../shared/widgets/note_presence_bar.dart';
import '../../../core/realtime/ws_client.dart';
import '../../../features/groups/providers/groups_provider.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  final String? noteId;

  const NoteEditorScreen({super.key, this.noteId});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _checklistCtrl = TextEditingController();
  bool _isDirty = false;
  bool _isSaving = false;
  bool _hasSavedOnce = false;
  Timer? _debounce;

  late final ConfettiController _confettiCtrl = ConfettiController(
    duration: const Duration(seconds: 3),
  );

  // Presence & typing
  StreamSubscription? _wsSub;
  WsClient? _wsClient;
  final List<NoteViewer> _viewers = [];
  String? _typingUserId;
  Timer? _typingTimer;
  Timer? _typingDebounce;

  bool get _isNew => widget.noteId == null;

  @override
  void initState() {
    super.initState();
    if (!_isNew) {
      _setupPresence();
    }
  }

  void _setupPresence() {
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
    _confettiCtrl.dispose();
    _debounce?.cancel();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _checklistCtrl.dispose();
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
    if (!_isDirty) {
      _titleCtrl.text = note.title;
      _contentCtrl.text = note.content;
    }

    return PopScope(
      canPop: !_isSaving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop && _isDirty) {
          _debounce?.cancel();
          await _saveNote(note.id);
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
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
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

            // Checklist
            if (note.checklistItems.isNotEmpty) ...[
              Text('Чеклист', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: note.checklistItems.length,
                onReorderItem: (oldIndex, newIndex) =>
                    _reorderChecklistAdjusted(note, oldIndex, newIndex),
                itemBuilder: (context, index) {
                  final item = note.checklistItems[index];
                  return _ChecklistItemTile(
                    key: ValueKey(item.id),
                    item: item,
                    noteId: note.id,
                    index: index,
                    onToggle: (completed) {
                      ref
                          .read(noteDetailProvider(note.id).notifier)
                          .toggleChecklistItem(item.id, completed);
                      if (completed && note.checklistItems.length > 1) {
                        final allDone = note.checklistItems.every(
                          (i) => i.id == item.id || i.completed,
                        );
                        if (allDone) {
                          HapticFeedback.mediumImpact();
                          _confettiCtrl.play();
                        }
                      }
                    },
                    onDelete: () => ref
                        .read(noteDetailProvider(note.id).notifier)
                        .deleteChecklistItem(item.id),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],

            // Add checklist item
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _checklistCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Добавить пункт...',
                      prefixIcon: Icon(Icons.add, size: 18),
                    ),
                    onSubmitted: (text) => _addChecklistItem(note.id, text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

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
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      note.images[index].url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],

            // Upload image button
            OutlinedButton.icon(
              icon: const Icon(Icons.image_outlined),
              label: const Text('Прикрепить изображение'),
              onPressed: () => _pickAndUploadImage(note.id),
            ),
          ],
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiCtrl,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                numberOfParticles: 30,
                emissionFrequency: 0.05,
                gravity: 0.1,
                maxBlastForce: 30,
                minBlastForce: 10,
                colors: const [
                  Color(0xFFFF6B6B),
                  Color(0xFFF59F00),
                  Color(0xFFFFD43B),
                  Color(0xFF69DB7C),
                  Color(0xFF4DABF7),
                  Color(0xFF9775FA),
                  Color(0xFFF783AC),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
      await ref.read(notesProvider.notifier).updateNote(
            noteId,
            title: title,
            content: _contentCtrl.text,
          );
      if (mounted) {
        setState(() {
          _isDirty = false;
          _hasSavedOnce = true;
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

  Future<void> _addChecklistItem(String noteId, String text) async {
    if (text.trim().isEmpty) return;
    _checklistCtrl.clear();
    await ref.read(noteDetailProvider(noteId).notifier).addChecklistItem(text.trim());
  }

  Future<void> _pickAndUploadImage(String noteId) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    await ref.read(noteDetailProvider(noteId).notifier).uploadImage(picked.path);
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
        const SnackBar(content: Text('Нет доступных контекстов для переноса')),
      );
      return;
    }

    final target = await showModalBottomSheet<_MoveContextTarget>(
      context: context,
      showDragHandle: true,
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
        const SnackBar(content: Text('Контекст не выбран')),
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

  const _ChecklistItemTile({
    super.key,
    required this.item,
    required this.noteId,
    required this.index,
    required this.onToggle,
    required this.onDelete,
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

  @override
  void didUpdateWidget(covariant _ChecklistItemTile old) {
    super.didUpdateWidget(old);
    if (old.item.completed != widget.item.completed && widget.item.completed) {
      _bounceCtrl.forward(from: 0);
      HapticFeedback.lightImpact();
    }
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: widget.index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.drag_handle, size: 20, color: AppColors.fgSoft),
            ),
          ),
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
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: widget.onDelete,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
