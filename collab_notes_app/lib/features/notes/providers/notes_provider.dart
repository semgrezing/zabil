import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note_model.dart';
import '../services/notes_service.dart';

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

final notesProvider = AsyncNotifierProvider<NotesNotifier, List<NoteModel>>(
  NotesNotifier.new,
);

class NotesNotifier extends AsyncNotifier<List<NoteModel>> {
  NotesService get _service => ref.read(notesServiceProvider);

  @override
  Future<List<NoteModel>> build() async {
    final filter = ref.watch(notesFilterProvider);
    return _service.getNotes(
      groupId: filter.groupId,
      personal: filter.personal,
      search: filter.search,
      archived: filter.showArchived ? true : false,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _service.getNotes(
          groupId: ref.read(notesFilterProvider).groupId,
          personal: ref.read(notesFilterProvider).personal,
          search: ref.read(notesFilterProvider).search,
          archived: ref.read(notesFilterProvider).showArchived ? true : false,
        ));
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
    state = state.whenData((notes) => notes.where((n) => n.id != id).toList());
  }

  Future<bool> archiveNote(String id) async {
    final result = await _service.archiveNote(id);
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
    await refresh();
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
