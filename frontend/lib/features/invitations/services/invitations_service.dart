import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/api_endpoints.dart';
import '../models/invitation_model.dart';
import '../models/invitation_action_result.dart';

class InvitationsService {
  final Dio _dio = ApiClient.create();

  Future<List<InvitationModel>> getIncoming() async {
    final response = await _dio.get(ApiEndpoints.incomingInvitations);
    return (response.data as List)
        .map((e) => InvitationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> sendInvitation(String groupId, String username) async {
    await _dio.post(ApiEndpoints.invitations, data: {
      'groupId': groupId,
      'username': username,
    });
  }

  Future<InvitationActionResult> accept(String id) async {
    final response = await _dio.post(ApiEndpoints.acceptInvitation(id));
    final data = response.data;
    return InvitationActionResult.fromJson(
      data is Map<String, dynamic> ? data : null,
      fallbackStatus: 'accepted',
    );
  }

  Future<InvitationActionResult> decline(String id) async {
    final response = await _dio.post(ApiEndpoints.declineInvitation(id));
    final data = response.data;
    return InvitationActionResult.fromJson(
      data is Map<String, dynamic> ? data : null,
      fallbackStatus: 'declined',
    );
  }
}
