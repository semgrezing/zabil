import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/realtime/ws_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/chat_message.dart';
import '../services/chats_service.dart';

final chatsServiceProvider = Provider<ChatsService>((ref) => ChatsService());

// ─── Personal conversations list ─────────────────────────────────────────────

final personalConversationsProvider = AsyncNotifierProvider<
    PersonalConversationsNotifier, List<PersonalChatPreview>>(
  PersonalConversationsNotifier.new,
);

class PersonalConversationsNotifier
    extends AsyncNotifier<List<PersonalChatPreview>> {
  ChatsService get _service => ref.read(chatsServiceProvider);
  StreamSubscription? _wsSub;

  @override
  Future<List<PersonalChatPreview>> build() async {
    _wsSub?.cancel();
    final ws = ref.read(wsClientProvider);
    _wsSub = ws.events.listen((event) {
      if (event is PersonalMessageEvent ||
          event is PersonalReadReceiptEvent ||
          event is WsReconnectedEvent) {
        refresh();
        return;
      }
      if (event is UserOnlineStatusEvent) {
        state = state.whenData(
          (items) => items
              .map(
                (item) => item.user['id'] == event.userId
                    ? item.copyWithPresence(
                        isOnline: event.isOnline,
                        lastSeenAt: event.lastSeenAt,
                      )
                    : item,
              )
              .toList(),
        );
      }
    });
    ref.onDispose(() {
      _wsSub?.cancel();
      _wsSub = null;
    });
    return _service.getPersonalConversations();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _service.getPersonalConversations());
  }
}

// ─── Group chat (с optional noteId) ─────────────────────────────────────────

class GroupChatKey {
  final String groupId;
  final String? noteId;
  const GroupChatKey(this.groupId, this.noteId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GroupChatKey && other.groupId == groupId && other.noteId == noteId);

  @override
  int get hashCode => Object.hash(groupId, noteId);
}

final groupChatProvider = AsyncNotifierProvider.family<GroupChatNotifier,
    List<GroupChatMessage>, GroupChatKey>(
  GroupChatNotifier.new,
);

class GroupChatNotifier
    extends FamilyAsyncNotifier<List<GroupChatMessage>, GroupChatKey> {
  ChatsService get _service => ref.read(chatsServiceProvider);
  StreamSubscription? _wsSub;

  @override
  Future<List<GroupChatMessage>> build(GroupChatKey arg) async {
    _wsSub?.cancel();
    final ws = ref.read(wsClientProvider);
    _wsSub = ws.events.listen((event) {
      if (event is WsReconnectedEvent) {
        _refetch();
        return;
      }
      if (event is GroupMessageEvent) {
        final data = event.data;
        if (data['groupId'] != arg.groupId) return;
        // Если открыт note-chat — показываем только сообщения с этой noteId
        if (arg.noteId != null && data['noteId'] != arg.noteId) return;
        try {
          final message = GroupChatMessage.fromJson(data);
          state = state.whenData((list) {
            if (list.any((m) => m.id == message.id)) return list; // дубликат
            return [message, ...list];
          });
        } catch (_) {}
      } else if (event is GroupReadReceiptEvent) {
        if (event.groupId != arg.groupId) return;
        final ids = event.messageIds.toSet();
        final myId = ref.read(authStateProvider).valueOrNull?.user?.id;
        state = state.whenData((list) => list.map((m) {
              if (!ids.contains(m.id)) return m;
              // Increment readCount if the reader is not the sender
              final isOtherReader = event.readerId != m.senderId;
              return m.copyWith(
                readCount: isOtherReader ? m.readCount + 1 : m.readCount,
                isReadByMe: event.readerId == myId ? true : m.isReadByMe,
              );
            }).toList());
      }
    });
    ref.onDispose(() {
      _wsSub?.cancel();
      _wsSub = null;
    });
    final messages = await _service.getGroupMessages(arg.groupId, noteId: arg.noteId);
    // Mark messages as read after loading (fire-and-forget)
    _service.markGroupRead(arg.groupId).catchError((_) {});
    return messages;
  }

  Future<void> _refetch() async {
    state = await AsyncValue.guard(
      () => _service.getGroupMessages(arg.groupId, noteId: arg.noteId),
    );
  }

  Future<GroupChatMessage> send({
    String? body,
    String? imageUrl,
    String? imageMimeType,
    int? imageSize,
    bool? imageCompressed,
  }) async {
    final message = await _service.sendGroupMessage(
      arg.groupId,
      body,
      noteId: arg.noteId,
      imageUrl: imageUrl,
      imageMimeType: imageMimeType,
      imageSize: imageSize,
      imageCompressed: imageCompressed,
    );
    state = state.whenData((list) {
      if (list.any((m) => m.id == message.id)) return list; // дубликат от WS
      return [message, ...list];
    });
    // Mark new messages as read since we're actively in the chat
    _service.markGroupRead(arg.groupId).catchError((_) {});
    return message;
  }
}

// ─── Personal chat (1:1) ────────────────────────────────────────────────────

final personalChatProvider = AsyncNotifierProvider.family<PersonalChatNotifier,
    List<PersonalChatMessage>, String>(
  PersonalChatNotifier.new,
);

class PersonalChatNotifier
    extends FamilyAsyncNotifier<List<PersonalChatMessage>, String> {
  ChatsService get _service => ref.read(chatsServiceProvider);
  StreamSubscription? _wsSub;
  Timer? _markReadDebounce;

  @override
  Future<List<PersonalChatMessage>> build(String otherUserId) async {
    _wsSub?.cancel();
    final ws = ref.read(wsClientProvider);
    _wsSub = ws.events.listen((event) {
      if (event is WsReconnectedEvent) {
        _refetch();
        return;
      }
      if (event is PersonalMessageEvent) {
        final data = event.data;
        final sender = data['senderId'];
        final receiver = data['receiverId'];
        // Сообщение относится к нашему собеседнику?
        if (sender != otherUserId && receiver != otherUserId) return;
        try {
          final message = PersonalChatMessage.fromJson(data);
          state = state.whenData((list) {
            if (list.any((m) => m.id == message.id)) return list;
            return [message, ...list];
          });

          final myUserId = ref.read(authStateProvider).valueOrNull?.user?.id;
          if (sender == arg && receiver == myUserId) {
            _scheduleMarkRead();
          }
        } catch (_) {}
      } else if (event is PersonalReadReceiptEvent) {
        if (event.peerUserId != arg) return;
        if (event.messageIds.isEmpty) return;
        final ids = event.messageIds.toSet();
        state = state.whenData((list) => list
            .map((m) => ids.contains(m.id)
                ? m.copyWith(readAt: event.readAt)
                : m)
            .toList());
      }
    });
    ref.onDispose(() {
      _wsSub?.cancel();
      _wsSub = null;
      _markReadDebounce?.cancel();
    });
    return _service.getPersonalMessages(otherUserId);
  }

  Future<void> _refetch() async {
    state = await AsyncValue.guard(
      () => _service.getPersonalMessages(arg),
    );
  }

  Future<PersonalChatMessage> send({
    String? body,
    String? imageUrl,
    String? imageMimeType,
    int? imageSize,
    bool? imageCompressed,
  }) async {
    final message = await _service.sendPersonalMessage(
      arg,
      body,
      imageUrl: imageUrl,
      imageMimeType: imageMimeType,
      imageSize: imageSize,
      imageCompressed: imageCompressed,
    );
    state = state.whenData((list) {
      if (list.any((m) => m.id == message.id)) return list;
      return [message, ...list];
    });
    return message;
  }

  Future<void> markRead() async {
    try {
      await _service.markPersonalRead(arg);
      final myUserId = ref.read(authStateProvider).valueOrNull?.user?.id;
      final now = DateTime.now();
      state = state.whenData((list) => list
          .map((m) => (m.senderId == arg && m.receiverId == myUserId && m.readAt == null)
              ? m.copyWith(readAt: now)
              : m)
          .toList());
      ref.invalidate(personalConversationsProvider);
    } catch (_) {}
  }

  void _scheduleMarkRead() {
    _markReadDebounce?.cancel();
    _markReadDebounce = Timer(const Duration(milliseconds: 450), () {
      markRead();
    });
  }
}
