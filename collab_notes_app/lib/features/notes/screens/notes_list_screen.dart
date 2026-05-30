import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_icons/solar_icons.dart';
import '../providers/notes_provider.dart';
import '../models/note_model.dart';
import '../widgets/note_card.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_dimensions.dart';
import '../../../features/groups/providers/groups_provider.dart';
import '../../../shared/widgets/app_chip.dart';

class NotesListScreen extends ConsumerStatefulWidget {
  const NotesListScreen({super.key});

  @override
  ConsumerState<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends ConsumerState<NotesListScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  static const _layoutPrefKey = 'notes.layout.grid';

  String? _routeGroupId;
  bool _routePersonal = false;
  bool _showSearch = false;
  bool _gridView = false;

  @override
  void initState() {
    super.initState();
    _loadLayoutPreference();
    _searchFocus.onKeyEvent = _handleSearchKeyEvent;
  }

  KeyEventResult _handleSearchKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _searchCtrl.text.isEmpty) {
      setState(() => _showSearch = false);
      ref.read(notesFilterProvider.notifier).update(
            (s) => s.copyWith(search: ''),
          );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uri = GoRouterState.of(context).uri;
    final groupId = uri.queryParameters['groupId'];
    final personal = uri.queryParameters['personal'] == 'true';

    if (groupId != _routeGroupId || personal != _routePersonal) {
      _routeGroupId = groupId;
      _routePersonal = personal;
      ref.read(notesFilterProvider.notifier).update(
            (s) => NotesFilter(
              groupId: (groupId != null && groupId.isNotEmpty) ? groupId : null,
              personal: personal,
              search: s.search,
              showArchived: s.showArchived,
            ),
          );
    }
  }

  Future<void> _loadLayoutPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _gridView = prefs.getBool(_layoutPrefKey) ?? false;
    });
  }

  Future<void> _toggleLayout() async {
    final next = !_gridView;
    setState(() => _gridView = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_layoutPrefKey, next);
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(notesFilterProvider);
    final notesAsync = ref.watch(notesProvider);
    final groupsAsync = ref.watch(groupsProvider);
    final groups = groupsAsync.valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                autofocus: true,
                style: const TextStyle(color: AppColors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Поиск заметок...',
                  hintStyle: TextStyle(
                    color: AppColors.fgSoft.withValues(alpha: 0.6),
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceGlass,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(SolarIconsOutline.closeCircle, size: 20),
                    onPressed: () {
                      setState(() => _showSearch = false);
                      _searchCtrl.clear();
                      ref.read(notesFilterProvider.notifier).update(
                            (s) => s.copyWith(search: ''),
                          );
                    },
                  ),
                ),
                onChanged: (value) {
                  ref.read(notesFilterProvider.notifier).update(
                        (s) => s.copyWith(search: value),
                      );
                },
              )
            : const Text('Заметки'),
        actions: _showSearch
            ? []
            : [
                IconButton(
                  icon: const Icon(SolarIconsOutline.magnifier),
                  tooltip: 'Поиск',
                  onPressed: () {
                    setState(() => _showSearch = true);
                  },
                ),
                IconButton(
                  icon: Icon(
                    filter.showArchived
                        ? SolarIconsBold.archive
                        : SolarIconsOutline.archive,
                  ),
                  tooltip: filter.showArchived
                      ? 'Скрыть архив'
                      : 'Показать архив',
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
          // Filter chips + view toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                // Filter chips (scrollable with fade)
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.black,
                          Colors.black,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.85, 1.0],
                      ).createShader(bounds),
                      blendMode: BlendMode.dstIn,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: AppChip(
                              label: 'Все',
                              selected:
                                  filter.groupId == null && !filter.personal,
                              onPressed: () => ref
                                  .read(notesFilterProvider.notifier)
                                  .update((s) => NotesFilter(
                                        search: s.search,
                                        showArchived: s.showArchived,
                                      )),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: AppChip(
                              label: 'Личное',
                              selected: filter.personal,
                              onPressed: () => ref
                                  .read(notesFilterProvider.notifier)
                                  .update(
                                    (s) => s.copyWith(
                                        personal: true, groupId: null),
                                  ),
                            ),
                          ),
                          ...groups.map(
                            (g) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: AppChip(
                                label: g.title,
                                selected: filter.groupId == g.id &&
                                    !filter.personal,
                                onPressed: () => ref
                                    .read(notesFilterProvider.notifier)
                                    .update(
                                      (s) => s.copyWith(
                                          groupId: g.id, personal: false),
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // View toggle (static, right side)
                _ViewToggle(
                  isGrid: _gridView,
                  onToggle: _toggleLayout,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

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
                          SolarIconsOutline.notes,
                          size: 48,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          filter.showArchived
                              ? 'Архив пуст'
                              : 'Нет заметок. Создайте первую!',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }

                Widget contentBuilder(int index) {
                  final note = notes[index];
                  return NoteCard(
                    note: note,
                    onTap: () => context.go('/notes/${note.id}'),
                    onArchive: () => _archiveNote(context, ref, note),
                    onDelete: () => _confirmDelete(context, ref, note),
                    onMove: () => _moveNote(context, ref, note),
                    onTogglePin: () => _togglePin(context, ref, note),
                    onColorChanged: (color) =>
                        _setNoteColor(context, ref, note, color),
                  );
                }

                if (_gridView) {
                  return RefreshIndicator(
                    color: AppColors.white,
                    backgroundColor: AppColors.bg3,
                    displacement: 60,
                    strokeWidth: 2.5,
                    onRefresh: () =>
                        ref.read(notesProvider.notifier).refresh(),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = constraints.maxWidth >= 1200
                            ? 4
                            : constraints.maxWidth >= 800
                                ? 3
                                : 2;
                        return MasonryGridView.count(
                          padding:
                              const EdgeInsets.fromLTRB(12, 4, 12, 80),
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          itemCount: notes.length,
                          itemBuilder: (context, index) {
                            final note = notes[index];
                            return NoteCard(
                              note: note,
                              compactMode: true,
                              onTap: () =>
                                  context.go('/notes/${note.id}'),
                              onArchive: () =>
                                  _archiveNote(context, ref, note),
                              onDelete: () =>
                                  _confirmDelete(context, ref, note),
                              onMove: () =>
                                  _moveNote(context, ref, note),
                              onTogglePin: () =>
                                  _togglePin(context, ref, note),
                              onColorChanged: (color) =>
                                  _setNoteColor(context, ref, note, color),
                            );
                          },
                        );
                      },
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(notesProvider.notifier).refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                    itemCount: notes.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        contentBuilder(index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: null,
    );
  }

  Future<void> _archiveNote(
      BuildContext context, WidgetRef ref, NoteModel note) async {
    try {
      final archived =
          await ref.read(notesProvider.notifier).archiveNote(note.id);
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
  }

  Future<void> _togglePin(
      BuildContext context, WidgetRef ref, NoteModel note) async {
    try {
      await ref.read(notesProvider.notifier).togglePin(note.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось закрепить: $e')),
      );
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, NoteModel note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить заметку?'),
        content: Text('«${note.title}» будет удалена.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(notesProvider.notifier).deleteNote(note.id);
    }
  }

  Future<void> _moveNote(
      BuildContext context, WidgetRef ref, NoteModel note) async {
    final groups = ref.read(groupsProvider).valueOrNull ?? [];
    final personal = ref.read(personalContextProvider).valueOrNull;

    final contexts = <_NoteContextTarget>[
      if (personal != null && !note.isPersonal)
        _NoteContextTarget.personal(personal.id),
      ...groups
          .where((g) => g.id != note.groupId)
          .map((g) => _NoteContextTarget.group(g.id, g.title)),
    ];

    if (contexts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Нет доступных контекстов для переноса')),
      );
      return;
    }

    final target = await _pickMoveTarget(context, contexts);
    if (target == null) return;

    try {
      await ref.read(notesProvider.notifier).moveNote(
            note.id,
            targetGroupId: target.personal ? null : target.id,
            targetPersonal: target.personal,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Заметка перемещена: ${target.title}')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось перенести заметку: $e')),
      );
    }
  }

  Future<void> _setNoteColor(
    BuildContext context,
    WidgetRef ref,
    NoteModel note,
    String? color,
  ) async {
    try {
      await ref.read(notesProvider.notifier).updateNote(
            note.id,
            colorLabel: color,
          );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось обновить цвет: $e')),
      );
    }
  }

  Future<_NoteContextTarget?> _pickMoveTarget(
    BuildContext context,
    List<_NoteContextTarget> contexts,
  ) {
    return showModalBottomSheet<_NoteContextTarget>(
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
                c.personal
                    ? SolarIconsOutline.user
                    : SolarIconsOutline.usersGroupRounded,
              ),
              title: Text(c.title),
              onTap: () => Navigator.pop(ctx, c),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ─── View Toggle ──────────────────────────────────────────────────────────────

class _ViewToggle extends StatelessWidget {
  final bool isGrid;
  final VoidCallback onToggle;

  const _ViewToggle({required this.isGrid, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (child, animation) {
          return RotationTransition(
            turns: Tween(begin: 0.5, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeInOut),
            ),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: Icon(
          isGrid ? SolarIconsOutline.listDown : SolarIconsOutline.widget,
          key: ValueKey(isGrid),
          size: 20,
          color: AppColors.white,
        ),
      ),
    );
  }
}

class _NoteContextTarget {
  final String id;
  final String title;
  final bool personal;

  const _NoteContextTarget._({
    required this.id,
    required this.title,
    required this.personal,
  });

  factory _NoteContextTarget.personal(String id) =>
      _NoteContextTarget._(id: id, title: 'Личное', personal: true);

  factory _NoteContextTarget.group(String id, String title) =>
      _NoteContextTarget._(id: id, title: title, personal: false);
}
