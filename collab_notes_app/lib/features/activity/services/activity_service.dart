import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/api_endpoints.dart';
import '../models/activity_item.dart';

class ActivityService {
  final Dio _dio = ApiClient.create();

  Future<List<ActivityItem>> getFeed({int limit = 50}) async {
    final response = await _dio.get(
      ApiEndpoints.activityFeed,
      queryParameters: {'limit': limit},
    );
    return (response.data as List)
        .map((e) => ActivityItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
