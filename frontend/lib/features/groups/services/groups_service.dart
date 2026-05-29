import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/api_endpoints.dart';
import '../models/group_model.dart';

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
}
