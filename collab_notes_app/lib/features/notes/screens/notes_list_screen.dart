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
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_dimensions.dart';
import '../../../features/groups/providers/groups_provider.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../core/utils/error_mapper.dart';

class NotesListScreen extends ConsumerStatefulWidget {
  const NotesListScreen({super.key});

  @override
  ConsumerState<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends ConsumerState<NotesListScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  static const _layoutPrefKey = 'notes.layout.grid';
  static const _archiveHintPrefKey = 'notes.archive.hint.shown';

  String? _routeGroupId;
  bool _routePersonal = false;
  bool _showSearch = false;
  bool _gridView = false;
  bool _archiveHintShown = false;

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
      _archiveHintShown = prefs.getBool(_archiveHintPrefKey) ?? false;
    });
  }

  Future<void> _maybeShowArchiveHint() async {
    if (_archiveHintShown || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Вы в архиве'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Выйти',
          onPressed: () {
            ref.read(notesFilterProvider.notifier).update(
                  (s) => s.copyWith(showArchived: false),
                );
          },
        ),
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_archiveHintPrefKey, true);
    if (!mounted) return;
    setState(() => _archiveHintShown = true);
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
    final realtimeBanner = ref.watch(notesRealtimeBannerProvider);
    final textHighlights = ref.watch(notesTextHighlightProvider);
    final checklistHighlights = ref.watch(notesChecklistHighlightProvider);
    final notesAsync = ref.watch(notesProvider);
    final groupsAsync = ref.watch(groupsProvider);
    final groups = groupsAsync.valueOrNull ?? [];
    final notesCounts = ref.watch(notesCountsProvider).valueOrNull ?? {};

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
                if (filter.showArchived)
                  TextButton.icon(
                    icon: const Icon(SolarIconsOutline.archiveUp, size: 18),
                    label: const Text('Выйти из архива'),
                    onPressed: () {
                      ref.read(notesFilterProvider.notifier).update(
                            (s) => s.copyWith(showArchived: false),
                          );
                    },
                  ),
                if (!filter.showArchived)
                  IconButton(
                    icon: const Icon(SolarIconsOutline.archive),
                    tooltip: 'Показать архив',
                    onPressed: () {
                      ref.read(notesFilterProvider.notifier).update(
                            (s) => s.copyWith(showArchived: true),
                          );
                      _maybeShowArchiveHint();
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
                              label: notesCounts.containsKey('all')
                                  ? 'Все (${notesCounts['all']})'
                                  : 'Все',
                              selected:
                                  filter.groupId == null && !filter.personal,
                                inactiveBackgroundColor: const Color(0xFF1A1A1A),
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
                              label: notesCounts.containsKey('personal')
                                  ? 'Личное (${notesCounts['personal']})'
                                  : 'Личное',
                              selected: filter.personal,
                                inactiveBackgroundColor: const Color(0xFF1A1A1A),
                              onPressed: () => ref
                                  .read(notesFilterProvider.notifier)
                                  .update(
                                    (s) => s.copyWith(
                                        personal: true, groupId: null),
                                  ),
                            ),
                          ),
                          ...groups.map(
                            (g) {
                              final count = notesCounts[g.id];
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: AppChip(
                                  label: count != null
                                      ? '${g.title} ($count)'
                                      : g.title,
                                  selected: filter.groupId == g.id &&
                                      !filter.personal,
                                  inactiveBackgroundColor: const Color(0xFF1A1A1A),
                                  onPressed: () => ref
                                      .read(notesFilterProvider.notifier)
                                      .update(
                                        (s) => s.copyWith(
                                            groupId: g.id, personal: false),
                                      ),
                                ),
                              );
                            },
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

          if (realtimeBanner)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                        'Есть новые изменения в заметках',
                        style: TextStyle(fontSize: 13, color: AppColors.fgSoft),
                      ),
                    ),
                    TextButton(
                      onPressed: () => ref.read(notesProvider.notifier).refresh(),
                      child: const Text('Обновить'),
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.read(notesRealtimeBannerProvider.notifier).state = false,
                      child: const Text('Позже'),
                    ),
                  ],
                ),
              ),
            ),

          // Notes list
          Expanded(
            child: notesAsync.when(
              loading: () => const _NotesListSkeleton(),
              error: (err, _) => Center(
                child: Text(mapError(err)),
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
                    highlightText: textHighlights.contains(note.id),
                    highlightChecklist: checklistHighlights.contains(note.id),
                    onTap: () {
                      ref.read(notesProvider.notifier).markNoteAsViewed(note.id);
                      context.go('/notes/${note.id}');
                    },
                    onArchive: () => _archiveNote(context, ref, note),
                    onDelete: () => _confirmDelete(context, ref, note),
                    onMove: () => _moveNote(context, ref, note),
                    onTogglePin: () => _togglePin(context, ref, note),
                    onColorChanged: (color) =>
                        _setNoteColor(context, ref, note, color),
                  );
                }

                final viewport = _gridView
                    ? RefreshIndicator(
                        key: const ValueKey('notes_grid_refresh'),
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
                            // A9: MasonryGridView.count already provides true masonry layout:
                            // each card sizes to its content (MainAxisSize.min in NoteCard),
                            // no mainAxisExtent is set, so cards don't stretch to row max height.
                            return MasonryGridView.count(
                              key: const PageStorageKey('notes_grid'),
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                              crossAxisCount: crossAxisCount,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              itemCount: notes.length,
                              itemBuilder: (context, index) {
                                final note = notes[index];
                                return NoteCard(
                                  key: ValueKey('grid_${note.id}'),
                                  note: note,
                                  compactMode: true,
                                  highlightText: textHighlights.contains(note.id),
                                  highlightChecklist: checklistHighlights.contains(note.id),
                                  onTap: () {
                                    ref.read(notesProvider.notifier).markNoteAsViewed(note.id);
                                    context.go('/notes/${note.id}');
                                  },
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
                      )
                    : RefreshIndicator(
                        key: const ValueKey('notes_list_refresh'),
                        onRefresh: () =>
                            ref.read(notesProvider.notifier).refresh(),
                        child: ListView.separated(
                          key: const PageStorageKey('notes_list'),
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                          itemCount: notes.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) => KeyedSubtree(
                            key: ValueKey('list_${notes[index].id}'),
                            child: contentBuilder(index),
                          ),
                        ),
                      );

                return KeyedSubtree(
                  key: ValueKey(_gridView ? 'notes_grid_view' : 'notes_list_view'),
                  child: viewport,
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
      _NoteContextTarget? restoreTarget;
      if (note.archived) {
        final contexts = _buildContextTargets(
          ref,
          note,
          includeCurrent: true,
        );
        if (contexts.isEmpty) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Нет доступных групп для восстановления'),
            ),
          );
          return;
        }

        restoreTarget = await _pickRestoreTarget(
          context,
          contexts,
          initial: _NoteContextTarget._(
            id: note.groupId,
            title: note.isPersonal ? 'Личное' : (note.groupTitle ?? 'Группа'),
            personal: note.isPersonal,
          ),
        );
        if (restoreTarget == null) {
          return;
        }

        final sourceChanged = restoreTarget.id != note.groupId ||
            restoreTarget.personal != note.isPersonal;
        if (sourceChanged) {
          await ref.read(notesProvider.notifier).moveNote(
                note.id,
                targetGroupId: restoreTarget.personal ? null : restoreTarget.id,
                targetPersonal: restoreTarget.personal,
              );
        }
      }

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
                : restoreTarget == null
                    ? 'Заметка восстановлена из архива'
                    : 'Восстановлено: ${restoreTarget.title}',
          ),
          action: archived
              ? SnackBarAction(
                  label: 'Перейти',
                  onPressed: () {
                    ref.read(notesFilterProvider.notifier).update(
                          (s) => s.copyWith(showArchived: true),
                        );
                    _maybeShowArchiveHint();
                  },
                )
              : null,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось архивировать: ${mapError(e)}')),
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
        SnackBar(content: Text('Не удалось закрепить: ${mapError(e)}')),
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
    final contexts = _buildContextTargets(ref, note, includeCurrent: false);

    if (contexts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Нет доступных групп для переноса')),
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
        SnackBar(content: Text('Не удалось перенести: ${mapError(e)}')),
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
        SnackBar(content: Text('Не удалось обновить цвет: ${mapError(e)}')),
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

  List<_NoteContextTarget> _buildContextTargets(
    WidgetRef ref,
    NoteModel note, {
    required bool includeCurrent,
  }) {
    final groups = ref.read(groupsProvider).valueOrNull ?? [];
    final personal = ref.read(personalContextProvider).valueOrNull;

    return <_NoteContextTarget>[
      if (personal != null && (includeCurrent || !note.isPersonal))
        _NoteContextTarget.personal(personal.id),
      ...groups
          .where((g) => includeCurrent || g.id != note.groupId)
          .map((g) => _NoteContextTarget.group(g.id, g.title)),
    ];
  }

  Future<_NoteContextTarget?> _pickRestoreTarget(
    BuildContext context,
    List<_NoteContextTarget> contexts, {
    required _NoteContextTarget initial,
  }) {
    return showModalBottomSheet<_NoteContextTarget>(
      context: context,
      showDragHandle: true,
      useRootNavigator: true,
      builder: (ctx) {
        var selectedId = initial.id;
        var selectedPersonal = initial.personal;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final selected = contexts.firstWhere(
              (c) => c.id == selectedId && c.personal == selectedPersonal,
              orElse: () => contexts.first,
            );

            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      'Восстановить заметку в',
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                  ),
                  ...contexts.map(
                    (c) {
                      final selectedNow =
                          c.id == selectedId && c.personal == selectedPersonal;
                      return ListTile(
                        onTap: () {
                          setModalState(() {
                            selectedId = c.id;
                            selectedPersonal = c.personal;
                          });
                        },
                        leading: Icon(
                          c.personal
                              ? SolarIconsOutline.user
                              : SolarIconsOutline.usersGroupRounded,
                        ),
                        title: Text(c.title),
                        trailing: Icon(
                          selectedNow
                              ? SolarIconsBold.checkCircle
                              : Icons.radio_button_unchecked,
                          size: 18,
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Отмена'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(ctx, selected),
                            child: const Text('Восстановить'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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

class _NotesListSkeleton extends StatefulWidget {
  const _NotesListSkeleton();

  @override
  State<_NotesListSkeleton> createState() => _NotesListSkeletonState();
}

class _NotesListSkeletonState extends State<_NotesListSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final offset = _controller.value;

        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment(-1.8 + offset * 2.6, -0.2),
              end: Alignment(-0.8 + offset * 2.6, 0.2),
              colors: const [
                Color(0xFF1D1F24),
                Color(0xFF2B2F37),
                Color(0xFF1D1F24),
              ],
              stops: const [0.15, 0.5, 0.85],
            ).createShader(rect);
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
            itemBuilder: (context, index) => _SkeletonNoteCard(index: index),
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemCount: 7,
          ),
        );
      },
    );
  }
}

class _SkeletonNoteCard extends StatelessWidget {
  final int index;

  const _SkeletonNoteCard({required this.index});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final height = 108.0 + (index % 3) * 18.0;

    return Container(
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(14),
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 140,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 180,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 72,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
