import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/api_endpoints.dart';
import '../models/note_model.dart';

const _unset = Object();

class NotesService {
  final Dio _dio = ApiClient.create();

  Future<List<NoteModel>> getNotes({
    String? groupId,
    bool personal = false,
    String? search,
    bool? archived,
  }) async {
    final response = await _dio.get(
      ApiEndpoints.notes,
      queryParameters: {
        if (groupId != null) 'groupId': groupId,
        if (personal) 'personal': 'true',
        if (search != null && search.isNotEmpty) 'search': search,
        if (archived != null) 'archived': archived.toString(),
      },
    );
    return (response.data as List)
        .map((e) => NoteModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<NoteModel> getNoteById(String id) async {
    final response = await _dio.get(ApiEndpoints.noteById(id));
    return NoteModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<NoteModel> createNote({
    String? groupId,
    bool personal = false,
    required String title,
    String content = '',
    String? colorLabel,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.notes,
      data: {
        if (groupId != null) 'groupId': groupId,
        if (personal) 'personal': true,
        'title': title,
        'content': content,
        if (colorLabel != null) 'colorLabel': colorLabel,
      },
    );
    return NoteModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<NoteModel> updateNote(
    String id, {
    String? title,
    String? content,
    Object? colorLabel = _unset,
    bool? pinned,
  }) async {
    final response = await _dio.patch(
      ApiEndpoints.noteById(id),
      data: {
        if (title != null) 'title': title,
        if (content != null) 'content': content,
        if (!identical(colorLabel, _unset)) 'colorLabel': colorLabel as String?,
        if (pinned != null) 'pinned': pinned,
      },
    );
    return NoteModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<NoteModel> moveNote(
    String id, {
    String? targetGroupId,
    bool targetPersonal = false,
  }) async {
    final response = await _dio.patch(
      ApiEndpoints.moveNote(id),
      data: {
        if (targetGroupId != null) 'targetGroupId': targetGroupId,
        if (targetPersonal) 'targetPersonal': true,
      },
    );
    return NoteModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteNote(String id) async {
    await _dio.delete(ApiEndpoints.noteById(id));
  }

  Future<Map<String, dynamic>> archiveNote(String id) async {
    final response = await _dio.post(ApiEndpoints.archiveNote(id));
    return response.data as Map<String, dynamic>;
  }

  Future<ChecklistItem> addChecklistItem(String noteId, String text, {int? position}) async {
    final response = await _dio.post(
      ApiEndpoints.noteChecklist(noteId),
      data: {'text': text, if (position != null) 'position': position},
    );
    return ChecklistItem.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ChecklistItem> updateChecklistItem(
    String noteId,
    String itemId, {
    String? text,
    bool? completed,
    int? position,
  }) async {
    final response = await _dio.patch(
      ApiEndpoints.checklistItem(noteId, itemId),
      data: {
        if (text != null) 'text': text,
        if (completed != null) 'completed': completed,
        if (position != null) 'position': position,
      },
    );
    return ChecklistItem.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteChecklistItem(String noteId, String itemId) async {
    await _dio.delete(ApiEndpoints.checklistItem(noteId, itemId));
  }

  Future<NoteImage> uploadImage(String noteId, String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await _dio.post(
      '${ApiEndpoints.uploadNoteImage}?noteId=$noteId',
      data: formData,
    );
    return NoteImage.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteImage(String imageId) async {
    await _dio.delete(ApiEndpoints.deleteNoteImage(imageId));
  }
}
