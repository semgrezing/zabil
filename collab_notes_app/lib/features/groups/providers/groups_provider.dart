import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/group_model.dart';
import '../services/groups_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/realtime/ws_client.dart';

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
  StreamSubscription? _wsSub;

  @override
  Future<List<GroupModel>> build() async {
    final auth = ref.watch(authStateProvider);
    if (auth.valueOrNull?.isLoggedIn != true) return [];
    final myUserId = auth.valueOrNull?.user?.id;

    _wsSub?.cancel();
    _wsSub = ref.read(wsClientProvider).events.listen((event) {
      if (event is WsReconnectedEvent) {
        refresh();
        return;
      }
      if (event is UserOnlineStatusEvent) {
        state = state.whenData(
          (groups) => groups
              .map(
                (group) => GroupModel(
                  id: group.id,
                  title: group.title,
                  avatarUrl: group.avatarUrl,
                  isPersonal: group.isPersonal,
                  lastMessage: group.lastMessage,
                  unreadCount: group.unreadCount,
                  members: group.members
                      .map(
                        (member) => member.userId == event.userId
                            ? member.copyWithPresence(
                                isOnline: event.isOnline,
                                lastSeenAt: event.lastSeenAt,
                              )
                            : member,
                      )
                      .toList(),
                ),
              )
              .toList(),
        );
        return;
      }
      if (event is GroupMessageEvent) {
        final data = event.data;
        final groupId = data['groupId'] as String?;
        final senderId = data['senderId'] as String?;
        if (groupId == null) return;
        state = state.whenData((groups) => groups.map((g) {
          if (g.id != groupId) return g;
          final sender = data['sender'] as Map<String, dynamic>?;
          final newLast = GroupLastMessageModel(
            id: (data['id'] as String?) ?? '',
            body: (data['body'] as String?) ?? '',
            imageUrl: data['imageUrl'] as String?,
            createdAt: DateTime.tryParse(
                  (data['createdAt'] as String?) ?? '',
                ) ??
                DateTime.now(),
            sender: GroupLastMessageSenderModel.fromJson(
              sender?.cast<String, dynamic>() ?? const {},
            ),
          );
          final isFromMe = senderId == myUserId;
          return GroupModel(
            id: g.id,
            title: g.title,
            avatarUrl: g.avatarUrl,
            isPersonal: g.isPersonal,
            members: g.members,
            lastMessage: newLast,
            unreadCount: isFromMe ? g.unreadCount : g.unreadCount + 1,
          );
        }).toList());
        return;
      }
      if (event is GroupReadReceiptEvent) {
        if (event.readerId != myUserId) return;
        state = state.whenData((groups) => groups.map((g) {
          if (g.id != event.groupId) return g;
          return GroupModel(
            id: g.id,
            title: g.title,
            avatarUrl: g.avatarUrl,
            isPersonal: g.isPersonal,
            members: g.members,
            lastMessage: g.lastMessage,
            unreadCount: 0,
          );
        }).toList());
        return;
      }
    });
    ref.onDispose(() {
      _wsSub?.cancel();
      _wsSub = null;
    });
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
