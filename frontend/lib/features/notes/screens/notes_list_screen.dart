import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/notes_provider.dart';
import '../models/note_model.dart';
import '../widgets/note_card.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../features/groups/providers/groups_provider.dart';

class NotesListScreen extends ConsumerStatefulWidget {
  const NotesListScreen({super.key});

  @override
  ConsumerState<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends ConsumerState<NotesListScreen> {
  final _searchCtrl = TextEditingController();
  String? _routeGroupId;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final groupId = GoRouterState.of(context).uri.queryParameters['groupId'];
    if (groupId != _routeGroupId) {
      _routeGroupId = groupId;
      ref.read(notesFilterProvider.notifier).update(
            (s) => NotesFilter(
              groupId: (groupId != null && groupId.isNotEmpty) ? groupId : null,
              search: s.search,
              showArchived: s.showArchived,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(notesFilterProvider);
    final notesAsync = ref.watch(notesProvider);
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Заметки'),
        actions: [
          IconButton(
            icon: Icon(
              filter.showArchived ? Icons.archive : Icons.archive_outlined,
            ),
            tooltip: filter.showArchived ? 'Скрыть архив' : 'Показать архив',
            onPressed: () {
              ref.read(notesFilterProvider.notifier).update(
                    (s) => s.copyWith(showArchived: !s.showArchived),
                  );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Поиск заметок...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(notesFilterProvider.notifier).update(
                                (s) => s.copyWith(search: ''),
                              );
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                ref.read(notesFilterProvider.notifier).update(
                      (s) => s.copyWith(search: value),
                    );
              },
            ),
          ),

          // Group filter chips
          groupsAsync.whenOrNull(
            data: (groups) => groups.isEmpty
                ? const SizedBox.shrink()
                : SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: const Text('Все'),
                            selected: filter.groupId == null,
                            onSelected: (_) => ref
                                .read(notesFilterProvider.notifier)
                                .update((s) => NotesFilter(
                                      search: s.search,
                                      showArchived: s.showArchived,
                                    )),
                          ),
                        ),
                        ...groups.map(
                          (g) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(g.title),
                              selected: filter.groupId == g.id,
                              onSelected: (_) => ref
                                  .read(notesFilterProvider.notifier)
                                  .update((s) => s.copyWith(groupId: g.id)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ) ??
              const SizedBox.shrink(),

          // Notes list
          Expanded(
            child: notesAsync.when(
              loading: () => const AppLoader(),
              error: (err, _) => Center(
                child: Text('Ошибка загрузки: $err'),
              ),
              data: (notes) {
                if (notes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notes_outlined,
                          size: 48,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          filter.showArchived
                              ? 'Архив пуст'
                              : 'Нет заметок. Создайте первую!',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => ref.read(notesProvider.notifier).refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: notes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      return NoteCard(
                        note: note,
                        onTap: () => context.go('/notes/${note.id}'),
                        onArchive: () async {
                          try {
                            final archived = await ref
                                .read(notesProvider.notifier)
                                .archiveNote(note.id);
                            if (!context.mounted) return;
                            final messenger = ScaffoldMessenger.of(context);
                            messenger.clearSnackBars();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  archived
                                      ? 'Заметка отправлена в архив'
                                      : 'Заметка восстановлена из архива',
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Не удалось архивировать: $e')),
                            );
                          }
                        },
                        onDelete: () => _confirmDelete(context, ref, note),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _CreateNoteFab(),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, NoteModel note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить заметку?'),
        content: Text('«${note.title}» будет удалена.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(notesProvider.notifier).deleteNote(note.id);
    }
  }
}

class _CreateNoteFab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);

    return FloatingActionButton.extended(
      icon: const Icon(Icons.add),
      label: const Text('Заметка'),
      onPressed: () async {
        final groups = groupsAsync.valueOrNull ?? [];
        if (groups.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Сначала создайте или вступите в группу')),
          );
          return;
        }

        // If single group — go directly; if multiple — show picker
        if (groups.length == 1) {
          context.go('/notes/new?groupId=${groups.first.id}');
        } else {
          final selectedId = await _pickGroup(context, groups);
          if (selectedId != null && context.mounted) {
            context.go('/notes/new?groupId=$selectedId');
          }
        }
      },
    );
  }

  Future<String?> _pickGroup(BuildContext context, List<dynamic> groups) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Выберите группу', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ...groups.map(
            (g) => ListTile(
              title: Text(g.title as String),
              onTap: () => Navigator.pop(ctx, g.id as String),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
