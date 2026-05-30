import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/api_endpoints.dart';
import '../models/chat_user_profile.dart';
import '../models/chat_message.dart';

class ChatsService {
  final Dio _dio = ApiClient.create();

  // ─── Group / Note chat ────────────────────────────────────────────────────
  Future<List<GroupChatMessage>> getGroupMessages(
    String groupId, {
    String? noteId,
    int? limit,
    String? before,
  }) async {
    final response = await _dio.get(
      ApiEndpoints.groupChatMessages(groupId),
      queryParameters: {
        if (noteId != null) 'noteId': noteId,
        if (limit != null) 'limit': limit,
        if (before != null) 'before': before,
      },
    );
    return (response.data as List)
        .map((e) => GroupChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GroupChatMessage> sendGroupMessage(
    String groupId,
    String? body, {
    String? noteId,
    String? imageUrl,
    String? imageMimeType,
    int? imageSize,
    bool? imageCompressed,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.groupChatMessages(groupId),
      data: {
        if (body != null) 'body': body,
        if (noteId != null) 'noteId': noteId,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (imageMimeType != null) 'imageMimeType': imageMimeType,
        if (imageSize != null) 'imageSize': imageSize,
        if (imageCompressed != null) 'imageCompressed': imageCompressed,
      },
    );
    return GroupChatMessage.fromJson(response.data as Map<String, dynamic>);
  }

  // ─── Personal chats ──────────────────────────────────────────────────────
  Future<List<PersonalChatPreview>> getPersonalConversations() async {
    final response = await _dio.get(ApiEndpoints.personalChats);
    return (response.data as List)
        .map((e) => PersonalChatPreview.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<PersonalChatMessage>> getPersonalMessages(
    String userId, {
    int? limit,
    String? before,
  }) async {
    final response = await _dio.get(
      ApiEndpoints.personalMessages(userId),
      queryParameters: {
        if (limit != null) 'limit': limit,
        if (before != null) 'before': before,
      },
    );
    return (response.data as List)
        .map((e) => PersonalChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PersonalChatMessage> sendPersonalMessage(
    String userId,
    String? body, {
    String? imageUrl,
    String? imageMimeType,
    int? imageSize,
    bool? imageCompressed,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.personalMessages(userId),
      data: {
        if (body != null) 'body': body,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (imageMimeType != null) 'imageMimeType': imageMimeType,
        if (imageSize != null) 'imageSize': imageSize,
        if (imageCompressed != null) 'imageCompressed': imageCompressed,
      },
    );
    return PersonalChatMessage.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> uploadChatImage(
    String filePath, {
    required bool compressed,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await _dio.post(
      '${ApiEndpoints.uploadChatImage}?compressed=${compressed ? 'true' : 'false'}',
      data: formData,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> markPersonalRead(String userId) async {
    await _dio.post(ApiEndpoints.personalMarkRead(userId));
  }

  // ─── Users search (для нового личного чата) ──────────────────────────────
  Future<List<Map<String, String>>> searchUsers(String query) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.usersSearch,
        queryParameters: {'username': query},
      );
      final data = response.data;
      if (data is Map && data['user'] is Map) {
        return [
          Map<String, String>.from(
            (data['user'] as Map)
                .map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')),
          )
        ];
      }
      if (data is List) {
        return data
            .map((e) => Map<String, String>.from(
                (e as Map).map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''))))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return [];
      }
      rethrow;
    }
  }

  Future<ChatUserProfile> getUserProfile(String userId) async {
    final response = await _dio.get(ApiEndpoints.userPublicProfile(userId));
    return ChatUserProfile.fromJson(response.data as Map<String, dynamic>);
  }
}
