import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/api_endpoints.dart';
import '../models/group_model.dart';

class PersonalContextModel {
  final String id;
  final String title;

  const PersonalContextModel({required this.id, required this.title});

  factory PersonalContextModel.fromJson(Map<String, dynamic> json) =>
      PersonalContextModel(
        id: json['id'] as String,
        title: json['title'] as String? ?? 'Личное',
      );
}

class GroupsService {
  final Dio _dio = ApiClient.create();

  Future<List<GroupModel>> getGroups() async {
    final response = await _dio.get(ApiEndpoints.groups);
    return (response.data as List)
        .map((e) => GroupModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GroupModel> getGroupById(String id) async {
    final response = await _dio.get(ApiEndpoints.groupById(id));
    return GroupModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<GroupModel> createGroup(String title) async {
    final response = await _dio.post(ApiEndpoints.groups, data: {'title': title});
    return GroupModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteGroup(String id) async {
    await _dio.delete(ApiEndpoints.groupById(id));
  }

  Future<void> leaveGroup(String id) async {
    // Backend route — DELETE /groups/:id/leave (см. groups/routes.ts)
    await _dio.delete(ApiEndpoints.leaveGroup(id));
  }

  Future<PersonalContextModel> getPersonalContext() async {
    final response = await _dio.get(ApiEndpoints.groupsPersonalContext);
    return PersonalContextModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<GroupModel> updateGroupTitle(String id, String title) async {
    final response = await _dio.patch(
      ApiEndpoints.updateGroup(id),
      data: {'title': title},
    );
    return GroupModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> removeGroupMember(String groupId, String userId) async {
    await _dio.delete(ApiEndpoints.removeGroupMember(groupId, userId));
  }

  Future<GroupModel> uploadGroupAvatar(String groupId, String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await _dio.post(
      ApiEndpoints.groupAvatar(groupId),
      data: formData,
    );
    return GroupModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteGroupAvatar(String groupId) async {
    await _dio.delete(ApiEndpoints.groupAvatar(groupId));
  }

  Future<List<Map<String, dynamic>>> getGroupAvatarHistory(String groupId) async {
    final response = await _dio.get(ApiEndpoints.groupAvatarHistory(groupId));
    return (response.data as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> deleteGroupAvatarHistoryItem(String groupId, String historyId) async {
    await _dio.delete(ApiEndpoints.groupAvatarHistoryItem(groupId, historyId));
  }
}
