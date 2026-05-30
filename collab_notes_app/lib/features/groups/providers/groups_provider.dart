import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/group_model.dart';
import '../services/groups_service.dart';
import '../../auth/providers/auth_provider.dart';

final groupsServiceProvider = Provider<GroupsService>((ref) => GroupsService());

final personalContextProvider = FutureProvider<PersonalContextModel>((ref) {
  final auth = ref.watch(authStateProvider);
  if (auth.valueOrNull?.isLoggedIn != true) {
    throw StateError('Not authenticated');
  }
  return ref.read(groupsServiceProvider).getPersonalContext();
});

final groupsProvider =
    AsyncNotifierProvider<GroupsNotifier, List<GroupModel>>(GroupsNotifier.new);

class GroupsNotifier extends AsyncNotifier<List<GroupModel>> {
  GroupsService get _service => ref.read(groupsServiceProvider);

  @override
  Future<List<GroupModel>> build() async {
    final auth = ref.watch(authStateProvider);
    if (auth.valueOrNull?.isLoggedIn != true) return [];
    return _service.getGroups();
  }

  Future<void> createGroup(String title) async {
    final group = await _service.createGroup(title);
    state = state.whenData((groups) => [group, ...groups]);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _service.getGroups());
  }

  /// Удаляет группу (только владелец). Каскадно удалит notes/members/invitations
  /// на бэке.
  Future<void> deleteGroup(String id) async {
    await _service.deleteGroup(id);
    state = state.whenData((groups) => groups.where((g) => g.id != id).toList());
  }

  /// Выход из группы. Владелец не может выйти — сервер вернёт 400.
  Future<void> leaveGroup(String id) async {
    await _service.leaveGroup(id);
    state = state.whenData((groups) => groups.where((g) => g.id != id).toList());
  }

  Future<void> updateGroupTitle(String id, String title) async {
    final updated = await _service.updateGroupTitle(id, title);
    state = state.whenData(
      (groups) => groups.map((g) => g.id == id ? updated : g).toList(),
    );
  }

  Future<void> removeMember(String groupId, String userId) async {
    await _service.removeGroupMember(groupId, userId);
    await refresh();
  }

  Future<void> uploadAvatar(String groupId, String filePath) async {
    final updated = await _service.uploadGroupAvatar(groupId, filePath);
    state = state.whenData(
      (groups) => groups.map((g) => g.id == groupId ? updated : g).toList(),
    );
  }

  Future<void> deleteAvatar(String groupId) async {
    await _service.deleteGroupAvatar(groupId);
    await refresh();
  }
}
