import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note_model.dart';
import '../services/notes_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/realtime/ws_client.dart';

final notesServiceProvider = Provider<NotesService>((ref) => NotesService());
const _unset = Object();

// Notes list state
class NotesFilter {
  final String? groupId;
  final bool personal;
  final String? search;
  final bool showArchived;

  const NotesFilter({
    this.groupId,
    this.personal = false,
    this.search,
    this.showArchived = false,
  });

  NotesFilter copyWith({
    Object? groupId = _unset,
    bool? personal,
    Object? search = _unset,
    bool? showArchived,
  }) =>
      NotesFilter(
        groupId: identical(groupId, _unset) ? this.groupId : groupId as String?,
        personal: personal ?? this.personal,
        search: identical(search, _unset) ? this.search : search as String?,
        showArchived: showArchived ?? this.showArchived,
      );
}

final notesFilterProvider = StateProvider<NotesFilter>((ref) => const NotesFilter());
final notesRealtimeBannerProvider = StateProvider<bool>((ref) => false);
final notesTextHighlightProvider = StateProvider<Set<String>>((ref) => <String>{});
final notesChecklistHighlightProvider = StateProvider<Set<String>>((ref) => <String>{});

final notesProvider = AsyncNotifierProvider<NotesNotifier, List<NoteModel>>(
  NotesNotifier.new,
);

class NotesNotifier extends AsyncNotifier<List<NoteModel>> {
  NotesService get _service => ref.read(notesServiceProvider);

  final Map<String, List<NoteModel>> _queryCache = {};
  final Map<String, List<NoteModel>> _contextCache = {};
  Timer? _searchDebounce;
  Timer? _realtimeRefreshDebounce;
  StreamSubscription? _wsSub;
  final Map<String, Timer> _highlightTimers = {};
  bool _disposeHookRegistered = false;

  String _normalizeSearch(String? search) => search?.trim().toLowerCase() ?? '';

  String _contextKey({
    String? groupId,
    required bool personal,
    required bool showArchived,
  }) {
    return 'group:${groupId ?? ''}|personal:$personal|archived:$showArchived';
  }

  String _queryKey({
    String? groupId,
    required bool personal,
    required bool showArchived,
    String? search,
  }) {
    return '${_contextKey(groupId: groupId, personal: personal, showArchived: showArchived)}|search:${_normalizeSearch(search)}';
  }

  String _queryKeyFromFilter(NotesFilter filter) {
    return _queryKey(
      groupId: filter.groupId,
      personal: filter.personal,
      showArchived: filter.showArchived,
      search: filter.search,
    );
  }

  List<NoteModel> _applyLocalSearch(List<NoteModel> notes, String search) {
    if (search.isEmpty) return notes;
    return notes.where((n) {
      final title = n.title.toLowerCase();
      final content = n.content.toLowerCase();
      final group = (n.groupTitle ?? '').toLowerCase();
      return title.contains(search) || content.contains(search) || group.contains(search);
    }).toList(growable: false);
  }

  void _scheduleServerSearchSync(NotesFilter filter) {
    _searchDebounce?.cancel();
    final queryKey = _queryKeyFromFilter(filter);

    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final serverNotes = await _service.getNotes(
          groupId: filter.groupId,
          personal: filter.personal,
          search: filter.search,
          archived: filter.showArchived ? true : false,
        );
        _queryCache[queryKey] = serverNotes;

        if (_queryKeyFromFilter(ref.read(notesFilterProvider)) == queryKey) {
          state = AsyncData(serverNotes);
        }
      } catch (_) {
        // Keep local results if server-side search fails transiently.
      }
    });
  }

  void _clearCaches() {
    _queryCache.clear();
    _contextCache.clear();
  }

  @override
  Future<List<NoteModel>> build() async {
    final auth = ref.watch(authStateProvider);
    if (auth.valueOrNull?.isLoggedIn != true) return [];

    if (!_disposeHookRegistered) {
      _disposeHookRegistered = true;
      ref.onDispose(() {
        _searchDebounce?.cancel();
        _realtimeRefreshDebounce?.cancel();
        _wsSub?.cancel();
        for (final timer in _highlightTimers.values) {
          timer.cancel();
        }
        _highlightTimers.clear();
      });
    }

    _wsSub ??= ref.read(wsClientProvider).events.listen((event) {
      if (event is! PushNotificationEvent) return;
      final type = event.data['type']?.toString();
      if (type != 'new_note' && type != 'note_updated') {
        return;
      }

      final noteId = event.data['noteId']?.toString();
      if (noteId != null && noteId.isNotEmpty) {
        if (type == 'note_updated' || type == 'new_note') {
          final current = ref.read(notesTextHighlightProvider);
          ref.read(notesTextHighlightProvider.notifier).state = {
            ...current,
            noteId,
          };
        }
        _highlightTimers[noteId]?.cancel();
        _highlightTimers[noteId] = Timer(const Duration(seconds: 8), () {
          final textSet = {...ref.read(notesTextHighlightProvider)};
          textSet.remove(noteId);
          ref.read(notesTextHighlightProvider.notifier).state = textSet;

          final checklistSet = {...ref.read(notesChecklistHighlightProvider)};
          checklistSet.remove(noteId);
          ref.read(notesChecklistHighlightProvider.notifier).state = checklistSet;
          _highlightTimers.remove(noteId);
        });
      }

      final filter = ref.read(notesFilterProvider);
      final hasFilterContext =
          _normalizeSearch(filter.search).isNotEmpty ||
          filter.groupId != null ||
          filter.personal ||
          filter.showArchived;

      if (hasFilterContext) {
        ref.read(notesRealtimeBannerProvider.notifier).state = true;
        return;
      }

      _realtimeRefreshDebounce?.cancel();
      _realtimeRefreshDebounce =
          Timer(const Duration(milliseconds: 500), refresh);
    });

    _clearCaches();
    final filter = ref.watch(notesFilterProvider);
    final normalizedSearch = _normalizeSearch(filter.search);
    final contextKey = _contextKey(
      groupId: filter.groupId,
      personal: filter.personal,
      showArchived: filter.showArchived,
    );
    final queryKey = _queryKeyFromFilter(filter);

    final cachedQuery = _queryCache[queryKey];
    if (cachedQuery != null) return cachedQuery;

    if (normalizedSearch.isEmpty) {
      final cachedContext = _contextCache[contextKey];
      if (cachedContext != null) {
        _queryCache[queryKey] = cachedContext;
        return cachedContext;
      }

      final base = await _service.getNotes(
        groupId: filter.groupId,
        personal: filter.personal,
        archived: filter.showArchived ? true : false,
      );
      _contextCache[contextKey] = base;
      _queryCache[queryKey] = base;
      return base;
    }

    final cachedContext = _contextCache[contextKey];
    if (cachedContext != null) {
      final local = _applyLocalSearch(cachedContext, normalizedSearch);
      _scheduleServerSearchSync(filter);
      return local;
    }

    final base = await _service.getNotes(
      groupId: filter.groupId,
      personal: filter.personal,
      archived: filter.showArchived ? true : false,
    );
    _contextCache[contextKey] = base;
    final local = _applyLocalSearch(base, normalizedSearch);
    _scheduleServerSearchSync(filter);
    return local;
  }

  Future<void> refresh() async {
    _searchDebounce?.cancel();
    _clearCaches();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _service.getNotes(
          groupId: ref.read(notesFilterProvider).groupId,
          personal: ref.read(notesFilterProvider).personal,
          search: ref.read(notesFilterProvider).search,
          archived: ref.read(notesFilterProvider).showArchived ? true : false,
        ));

    final filter = ref.read(notesFilterProvider);
    final queryKey = _queryKeyFromFilter(filter);
    final contextKey = _contextKey(
      groupId: filter.groupId,
      personal: filter.personal,
      showArchived: filter.showArchived,
    );
    final current = state.valueOrNull;
    if (current != null) {
      _queryCache[queryKey] = current;
      if (_normalizeSearch(filter.search).isEmpty) {
        _contextCache[contextKey] = current;
      }
    }
    ref.read(notesRealtimeBannerProvider.notifier).state = false;
  }

  Future<NoteModel> createNote({
    String? groupId,
    bool personal = false,
    required String title,
    String content = '',
    String? colorLabel,
  }) async {
    final note = await _service.createNote(
      groupId: groupId,
      personal: personal,
      title: title,
      content: content,
      colorLabel: colorLabel,
    );
    _clearCaches();
    state = state.whenData((notes) => [note, ...notes]);
    return note;
  }

  Future<void> updateNote(
    String id, {
    String? title,
    String? content,
    Object? colorLabel = _unset,
    bool? pinned,
  }) async {
    final updated = await _service.updateNote(
      id,
      title: title,
      content: content,
      colorLabel: colorLabel,
      pinned: pinned,
    );
    _clearCaches();
    state = state.whenData(
      (notes) => notes.map((n) => n.id == id ? updated : n).toList(),
    );
  }

  Future<void> togglePin(String id) async {
    final current = state.valueOrNull?.firstWhere((n) => n.id == id);
    if (current == null) return;
    await updateNote(id, pinned: !current.pinned);
  }

  Future<void> deleteNote(String id) async {
    await _service.deleteNote(id);
    _clearCaches();
    state = state.whenData((notes) => notes.where((n) => n.id != id).toList());
  }

  Future<bool> archiveNote(String id) async {
    final result = await _service.archiveNote(id);
    _clearCaches();
    state = state.whenData((notes) => notes.where((n) => n.id != id).toList());
    return result['archived'] == true;
  }

  Future<void> moveNote(
    String id, {
    String? targetGroupId,
    bool targetPersonal = false,
  }) async {
    await _service.moveNote(
      id,
      targetGroupId: targetGroupId,
      targetPersonal: targetPersonal,
    );
    _clearCaches();
    await refresh();
  }

  void markNoteAsViewed(String noteId) {
    _highlightTimers[noteId]?.cancel();
    _highlightTimers.remove(noteId);

    final textSet = {...ref.read(notesTextHighlightProvider)};
    textSet.remove(noteId);
    ref.read(notesTextHighlightProvider.notifier).state = textSet;

    final checklistSet = {...ref.read(notesChecklistHighlightProvider)};
    checklistSet.remove(noteId);
    ref.read(notesChecklistHighlightProvider.notifier).state = checklistSet;
  }

}

// Single note provider
final noteDetailProvider =
    AsyncNotifierProviderFamily<NoteDetailNotifier, NoteModel, String>(
  NoteDetailNotifier.new,
);

class NoteDetailNotifier extends FamilyAsyncNotifier<NoteModel, String> {
  NotesService get _service => ref.read(notesServiceProvider);

  @override
  Future<NoteModel> build(String arg) async {
    return _service.getNoteById(arg);
  }

  Future<void> addChecklistItem(String text) async {
    final item = await _service.addChecklistItem(arg, text);
    state = state.whenData(
      (note) => NoteModel(
        id: note.id,
        groupId: note.groupId,
        groupTitle: note.groupTitle,
        isPersonal: note.isPersonal,
        title: note.title,
        content: note.content,
        colorLabel: note.colorLabel,
        archived: note.archived,
        pinned: note.pinned,
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
        creator: note.creator,
        checklistItems: [...note.checklistItems, item],
        images: note.images,
      ),
    );
  }

  Future<void> toggleChecklistItem(String itemId, bool completed) async {
    await _service.updateChecklistItem(arg, itemId, completed: completed);
    state = state.whenData(
      (note) => NoteModel(
        id: note.id,
        groupId: note.groupId,
        groupTitle: note.groupTitle,
        isPersonal: note.isPersonal,
        title: note.title,
        content: note.content,
        colorLabel: note.colorLabel,
        archived: note.archived,
        pinned: note.pinned,
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
        creator: note.creator,
        checklistItems: note.checklistItems
            .map((i) => i.id == itemId
                ? ChecklistItem(
                    id: i.id,
                    noteId: i.noteId,
                    text: i.text,
                    completed: completed,
                    position: i.position,
                  )
                : i)
            .toList(),
        images: note.images,
      ),
    );
  }

  Future<void> updateChecklistItemText(String itemId, String text) async {
    final updated = await _service.updateChecklistItem(arg, itemId, text: text);
    state = state.whenData(
      (note) => NoteModel(
        id: note.id,
        groupId: note.groupId,
        groupTitle: note.groupTitle,
        isPersonal: note.isPersonal,
        title: note.title,
        content: note.content,
        colorLabel: note.colorLabel,
        archived: note.archived,
        pinned: note.pinned,
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
        creator: note.creator,
        checklistItems: note.checklistItems
            .map((i) => i.id == itemId ? updated : i)
            .toList(),
        images: note.images,
      ),
    );
  }

  Future<void> deleteChecklistItem(String itemId) async {
    await _service.deleteChecklistItem(arg, itemId);
    state = state.whenData(
      (note) => NoteModel(
        id: note.id,
        groupId: note.groupId,
        groupTitle: note.groupTitle,
        isPersonal: note.isPersonal,
        title: note.title,
        content: note.content,
        colorLabel: note.colorLabel,
        archived: note.archived,
        pinned: note.pinned,
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
        creator: note.creator,
        checklistItems: note.checklistItems.where((i) => i.id != itemId).toList(),
        images: note.images,
      ),
    );
  }

  /// Optimistically reorder checklist items in local state.
  void reorderChecklistLocally(List<ChecklistItem> reorderedItems) {
    state = state.whenData(
      (note) => NoteModel(
        id: note.id,
        groupId: note.groupId,
        groupTitle: note.groupTitle,
        isPersonal: note.isPersonal,
        title: note.title,
        content: note.content,
        colorLabel: note.colorLabel,
        archived: note.archived,
        pinned: note.pinned,
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
        creator: note.creator,
        checklistItems: reorderedItems,
        images: note.images,
      ),
    );
  }

  Future<void> uploadImage(String filePath) async {
    final image = await _service.uploadImage(arg, filePath);
    state = state.whenData(
      (note) => NoteModel(
        id: note.id,
        groupId: note.groupId,
        groupTitle: note.groupTitle,
        isPersonal: note.isPersonal,
        title: note.title,
        content: note.content,
        colorLabel: note.colorLabel,
        archived: note.archived,
        pinned: note.pinned,
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
        creator: note.creator,
        checklistItems: note.checklistItems,
        images: [...note.images, image],
      ),
    );
  }

  void applyLocalTextEdits({
    required String title,
    required String content,
  }) {
    state = state.whenData(
      (note) => NoteModel(
        id: note.id,
        groupId: note.groupId,
        groupTitle: note.groupTitle,
        isPersonal: note.isPersonal,
        title: title,
        content: content,
        colorLabel: note.colorLabel,
        archived: note.archived,
        pinned: note.pinned,
        createdAt: note.createdAt,
        updatedAt: DateTime.now(),
        creator: note.creator,
        checklistItems: note.checklistItems,
        images: note.images,
      ),
    );
  }

  void applyRemoteSnapshot(NoteModel remote) {
    state = AsyncData(remote);
  }

  Future<void> deleteImage(String imageId) async {
    await _service.deleteImage(imageId);
    state = state.whenData(
      (note) => NoteModel(
        id: note.id,
        groupId: note.groupId,
        groupTitle: note.groupTitle,
        isPersonal: note.isPersonal,
        title: note.title,
        content: note.content,
        colorLabel: note.colorLabel,
        archived: note.archived,
        pinned: note.pinned,
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
        creator: note.creator,
        checklistItems: note.checklistItems,
        images: note.images.where((i) => i.id != imageId).toList(),
      ),
    );
  }
}
