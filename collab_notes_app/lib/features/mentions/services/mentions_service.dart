import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/api_endpoints.dart';
import '../models/mention_model.dart';

class MentionsService {
  final Dio _dio = ApiClient.create();

  Future<List<MentionModel>> getMentions() async {
    final response = await _dio.get(ApiEndpoints.mentions);
    return (response.data as List)
        .map((e) => MentionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markAllRead() async {
    await _dio.post(ApiEndpoints.mentionsReadAll);
  }
}
