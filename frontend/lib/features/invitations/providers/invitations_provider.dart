import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/invitation_model.dart';
import '../models/invitation_action_result.dart';
import '../services/invitations_service.dart';
import '../../../features/groups/providers/groups_provider.dart';

final invitationsServiceProvider =
    Provider<InvitationsService>((ref) => InvitationsService());

final invitationsProvider =
    AsyncNotifierProvider<InvitationsNotifier, List<InvitationModel>>(
  InvitationsNotifier.new,
);

class InvitationsNotifier extends AsyncNotifier<List<InvitationModel>> {
  late final InvitationsService _service;

  @override
  Future<List<InvitationModel>> build() async {
    _service = ref.read(invitationsServiceProvider);
    return _service.getIncoming();
  }

  Future<InvitationActionResult> accept(String id) async {
    final result = await _service.accept(id);
    if (result.status != 'pending') {
      state = state.whenData((list) => list.where((i) => i.id != id).toList());
    }
    final fresh = await _service.getIncoming();
    state = AsyncData(fresh);
    if (result.status == 'accepted') {
      ref.invalidate(groupsProvider);
    }
    return result;
  }

  Future<InvitationActionResult> decline(String id) async {
    final result = await _service.decline(id);
    if (result.status != 'pending') {
      state = state.whenData((list) => list.where((i) => i.id != id).toList());
    }
    final fresh = await _service.getIncoming();
    state = AsyncData(fresh);
    return result;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _service.getIncoming());
  }
}
