import 'package:flutter/foundation.dart';
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
  InvitationsService get _service => ref.read(invitationsServiceProvider);

  @override
  Future<List<InvitationModel>> build() async {
    return _service.getIncoming();
  }

  Future<InvitationActionResult> accept(String id) async {
    try {
      final result = await _service.accept(id);
      debugPrint('[invitations.provider] accept $id ok, refetching...');
      await _applyResult(id, result);
      return result;
    } catch (e, st) {
      debugPrint('[invitations.provider] accept ERR: $e\n$st');
      return _recoverAfterError(
        id,
        fallbackStatus: 'accepted',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<InvitationActionResult> decline(String id) async {
    try {
      final result = await _service.decline(id);
      debugPrint('[invitations.provider] decline $id ok');
      await _applyResult(id, result);
      return result;
    } catch (e, st) {
      debugPrint('[invitations.provider] decline ERR: $e\n$st');
      return _recoverAfterError(
        id,
        fallbackStatus: 'declined',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _applyResult(String id, InvitationActionResult result) async {
    if (result.status != 'pending') {
      state = state.whenData((list) => list.where((i) => i.id != id).toList());
    }
    final fresh = await _service.getIncoming();
    state = AsyncData(fresh);
    if (result.status == 'accepted') {
      ref.invalidate(groupsProvider);
    }
  }

  Future<InvitationActionResult> _recoverAfterError(
    String id, {
    required String fallbackStatus,
    required Object error,
    required StackTrace stackTrace,
  }) async {
    // Server мог уже применить accept/decline — пробуем перезапросить
    try {
      final fresh = await _service.getIncoming();
      final stillThere = fresh.any((i) => i.id == id);
      state = AsyncData(fresh);
      if (!stillThere) {
        if (fallbackStatus == 'accepted') {
          ref.invalidate(groupsProvider);
        }
        return InvitationActionResult(
          success: true,
          status: fallbackStatus,
          alreadyProcessed: true,
        );
      }
    } catch (_) {
      // refresh не вышел — оставляем как было и пробрасываем оригинал
    }

    Error.throwWithStackTrace(error, stackTrace);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _service.getIncoming());
  }
}
