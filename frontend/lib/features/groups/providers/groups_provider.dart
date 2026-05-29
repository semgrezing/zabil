import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/group_model.dart';
import '../services/groups_service.dart';

final groupsServiceProvider = Provider<GroupsService>((ref) => GroupsService());

final groupsProvider =
    AsyncNotifierProvider<GroupsNotifier, List<GroupModel>>(GroupsNotifier.new);

class GroupsNotifier extends AsyncNotifier<List<GroupModel>> {
  late final GroupsService _service;

  @override
  Future<List<GroupModel>> build() async {
    _service = ref.read(groupsServiceProvider);
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
}
