import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note_model.dart';
import '../services/notes_service.dart';

final notesServiceProvider = Provider<NotesService>((ref) => NotesService());

// Notes list state
class NotesFilter {
  final String? groupId;
  final String? search;
  final bool showArchived;

  const NotesFilter({this.groupId, this.search, this.showArchived = false});

  NotesFilter copyWith({String? groupId, String? search, bool? showArchived}) =>
      NotesFilter(
        groupId: groupId ?? this.groupId,
        search: search ?? this.search,
        showArchived: showArchived ?? this.showArchived,
      );
}

final notesFilterProvider = StateProvider<NotesFilter>((ref) => const NotesFilter());

final notesProvider = AsyncNotifierProvider<NotesNotifier, List<NoteModel>>(
  NotesNotifier.new,
);

class NotesNotifier extends AsyncNotifier<List<NoteModel>> {
  late final NotesService _service;

  @override
  Future<List<NoteModel>> build() async {
    _service = ref.read(notesServiceProvider);
    final filter = ref.watch(notesFilterProvider);
    return _service.getNotes(
      groupId: filter.groupId,
      search: filter.search,
      archived: filter.showArchived ? true : false,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _service.getNotes(
          groupId: ref.read(notesFilterProvider).groupId,
          search: ref.read(notesFilterProvider).search,
          archived: ref.read(notesFilterProvider).showArchived ? true : false,
        ));
  }

  Future<NoteModel> createNote({
    required String groupId,
    required String title,
    String content = '',
  }) async {
    final note = await _service.createNote(
      groupId: groupId,
      title: title,
      content: content,
    );
    state = state.whenData((notes) => [note, ...notes]);
    return note;
  }

  Future<void> updateNote(String id, {String? title, String? content}) async {
    final updated = await _service.updateNote(id, title: title, content: content);
    state = state.whenData(
      (notes) => notes.map((n) => n.id == id ? updated : n).toList(),
    );
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
}

// Single note provider
final noteDetailProvider =
    AsyncNotifierProviderFamily<NoteDetailNotifier, NoteModel, String>(
  NoteDetailNotifier.new,
);

class NoteDetailNotifier extends FamilyAsyncNotifier<NoteModel, String> {
  late final NotesService _service;

  @override
  Future<NoteModel> build(String arg) async {
    _service = ref.read(notesServiceProvider);
    return _service.getNoteById(arg);
  }

  Future<void> addChecklistItem(String text) async {
    final item = await _service.addChecklistItem(arg, text);
    state = state.whenData(
      (note) => NoteModel(
        id: note.id,
        groupId: note.groupId,
        title: note.title,
        content: note.content,
        archived: note.archived,
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
        title: note.title,
        content: note.content,
        archived: note.archived,
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
        title: note.title,
        content: note.content,
        archived: note.archived,
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
        creator: note.creator,
        checklistItems: note.checklistItems.where((i) => i.id != itemId).toList(),
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
        title: note.title,
        content: note.content,
        archived: note.archived,
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
        creator: note.creator,
        checklistItems: note.checklistItems,
        images: [...note.images, image],
      ),
    );
  }
}
