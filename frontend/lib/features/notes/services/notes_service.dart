import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/api_endpoints.dart';
import '../models/note_model.dart';

class NotesService {
  final Dio _dio = ApiClient.create();

  Future<List<NoteModel>> getNotes({
    String? groupId,
    String? search,
    bool? archived,
  }) async {
    final response = await _dio.get(
      ApiEndpoints.notes,
      queryParameters: {
        if (groupId != null) 'groupId': groupId,
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
    required String groupId,
    required String title,
    String content = '',
  }) async {
    final response = await _dio.post(
      ApiEndpoints.notes,
      data: {'groupId': groupId, 'title': title, 'content': content},
    );
    return NoteModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<NoteModel> updateNote(String id, {String? title, String? content}) async {
    final response = await _dio.patch(
      ApiEndpoints.noteById(id),
      data: {
        if (title != null) 'title': title,
        if (content != null) 'content': content,
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
  }) async {
    final response = await _dio.patch(
      ApiEndpoints.checklistItem(noteId, itemId),
      data: {
        if (text != null) 'text': text,
        if (completed != null) 'completed': completed,
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
}
