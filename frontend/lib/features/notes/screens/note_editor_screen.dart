import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/notes_provider.dart';
import '../models/note_model.dart';
import '../../../features/groups/providers/groups_provider.dart';
import '../../../shared/widgets/app_loader.dart';

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

  bool get _isNew => widget.noteId == null;

  @override
  void dispose() {
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
      canPop: !_isDirty || !_isSaving,
      onPopInvoked: (didPop) async {
        if (didPop || !_isDirty) return;
        await _saveNote(note.id);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isDirty ? 'Редактирование*' : 'Заметка'),
          actions: [
            if (_isDirty)
              IconButton(
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                onPressed: _isSaving ? null : () => _saveNote(note.id),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
              onChanged: (_) => setState(() => _isDirty = true),
            ),
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
              onChanged: (_) => setState(() => _isDirty = true),
            ),
            const Divider(height: 32),

            // Checklist
            if (note.checklistItems.isNotEmpty) ...[
              Text('Чеклист', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              ...note.checklistItems.map(
                (item) => _ChecklistItemTile(
                  item: item,
                  noteId: note.id,
                  onToggle: (completed) => ref
                      .read(noteDetailProvider(note.id).notifier)
                      .toggleChecklistItem(item.id, completed),
                  onDelete: () => ref
                      .read(noteDetailProvider(note.id).notifier)
                      .deleteChecklistItem(item.id),
                ),
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
                        color: Theme.of(context).colorScheme.surfaceVariant,
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
      ),
    );
  }

  Future<void> _saveNote(String noteId) async {
    setState(() => _isSaving = true);
    try {
      await ref.read(notesProvider.notifier).updateNote(
            noteId,
            title: _titleCtrl.text.trim(),
            content: _contentCtrl.text,
          );
      setState(() => _isDirty = false);
    } finally {
      setState(() => _isSaving = false);
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Новая заметка'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => _create(context, groupId),
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

  Future<void> _create(BuildContext context, String? groupId) async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите заголовок')),
      );
      return;
    }
    if (groupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Группа не выбрана')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final note = await ref.read(notesProvider.notifier).createNote(
            groupId: groupId,
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

class _ChecklistItemTile extends StatelessWidget {
  final ChecklistItem item;
  final String noteId;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  const _ChecklistItemTile({
    required this.item,
    required this.noteId,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: item.completed,
          onChanged: (v) => onToggle(v ?? false),
        ),
        Expanded(
          child: Text(
            item.text,
            style: item.completed
                ? TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  )
                : null,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 16),
          onPressed: onDelete,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}
