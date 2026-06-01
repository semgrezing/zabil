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
    final myUserId = ref.read(authStateProvider).valueOrNull?.user?.id;
    _wsSub = ws.events.listen((event) {
      if (event is WsReconnectedEvent) {
        refresh();
        return;
      }
      if (event is PersonalMessageEvent) {
        _applyPersonalMessageEvent(event.data, myUserId);
        return;
      }
      if (event is PersonalReadReceiptEvent) {
        _applyPersonalReadReceiptEvent(event, myUserId);
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

  void _applyPersonalMessageEvent(
    Map<String, dynamic> data,
    String? myUserId,
  ) {
    if (myUserId == null || myUserId.isEmpty) {
      refresh();
      return;
    }

    try {
      final message = PersonalChatMessage.fromJson(data);
      final partnerId = message.senderId == myUserId
          ? message.receiverId
          : message.senderId;
      if (partnerId.isEmpty) return;

      final currentItems = state.valueOrNull;
      if (currentItems == null) {
        refresh();
        return;
      }

      final index = currentItems.indexWhere((item) => item.user['id'] == partnerId);
      if (index < 0) {
        refresh();
        return;
      }

      final item = currentItems[index];
      final unreadCount = message.senderId == myUserId ? item.unreadCount : item.unreadCount + 1;
      final updated = item.copyWith(
        lastMessage: message,
        unreadCount: unreadCount,
      );

      final next = [...currentItems];
      next.removeAt(index);
      next.insert(0, updated);
      state = AsyncData(next);
    } catch (_) {
      refresh();
    }
  }

  void _applyPersonalReadReceiptEvent(
    PersonalReadReceiptEvent event,
    String? myUserId,
  ) {
    if (myUserId == null || myUserId.isEmpty) {
      refresh();
      return;
    }

    final currentItems = state.valueOrNull;
    if (currentItems == null) {
      refresh();
      return;
    }

    final partnerId = event.readerId == myUserId ? event.peerUserId : event.readerId;
    if (partnerId.isEmpty) return;

    final index = currentItems.indexWhere((item) => item.user['id'] == partnerId);
    if (index < 0) {
      refresh();
      return;
    }

    final item = currentItems[index];
    final unreadCount = event.readerId == myUserId ? 0 : item.unreadCount;
    final shouldMarkRead =
        event.peerUserId == myUserId && item.lastMessage.senderId == myUserId &&
        event.messageIds.contains(item.lastMessage.id);

    final updated = item.copyWith(
      unreadCount: unreadCount,
      lastMessage: shouldMarkRead
          ? item.lastMessage.copyWith(readAt: event.readAt)
          : item.lastMessage,
    );

    final next = [...currentItems];
    next[index] = updated;
    state = AsyncData(next);
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

final groupChatProvider = AsyncNotifierProvider.autoDispose
    .family<GroupChatNotifier, List<GroupChatMessage>, GroupChatKey>(
  GroupChatNotifier.new,
);

class GroupChatNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<GroupChatMessage>, GroupChatKey> {
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
      } else if (event is MessageDeletedEvent && event.kind == 'group') {
        final deletedId = event.messageId;
        state = state.whenData((list) => list
            .map((m) => m.id == deletedId ? m.asDeleted() : m)
            .toList());
      } else if (event is GroupReadReceiptEvent) {
        if (event.groupId != arg.groupId || event.messageIds.isEmpty) return;
        final readIds = event.messageIds.toSet();
        final readerId = event.readerId;
        final myUserId = ref.read(authStateProvider).valueOrNull?.user?.id;
        final markReadByMe = readerId == myUserId;

        state = state.whenData(
          (list) => list.map((m) {
            if (!readIds.contains(m.id)) return m;
            final isMyMessage = myUserId != null && m.senderId == myUserId;
            final nextReadCount =
                (isMyMessage && !markReadByMe && m.readCount == 0)
                    ? 1
                    : m.readCount;

            return m.copyWith(
              readCount: nextReadCount,
              isReadByMe: markReadByMe ? true : m.isReadByMe,
            );
          }).toList(),
        );
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
    String? parentMessageId,
  }) async {
    final message = await _service.sendGroupMessage(
      arg.groupId,
      body,
      noteId: arg.noteId,
      imageUrl: imageUrl,
      imageMimeType: imageMimeType,
      imageSize: imageSize,
      imageCompressed: imageCompressed,
      parentMessageId: parentMessageId,
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

final personalChatProvider = AsyncNotifierProvider.autoDispose
    .family<PersonalChatNotifier, List<PersonalChatMessage>, String>(
  PersonalChatNotifier.new,
);

class PersonalChatNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<PersonalChatMessage>, String> {
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
        if (event.messageIds.isEmpty) return;
        if (event.readerId != arg && event.peerUserId != arg) return;

        final readIds = event.messageIds.toSet();
        state = state.whenData((list) => list
            .map((m) => readIds.contains(m.id) ? m.copyWith(readAt: event.readAt) : m)
            .toList());
      } else if (event is MessageDeletedEvent && event.kind == 'personal') {
        final deletedId = event.messageId;
        state = state.whenData((list) => list
            .map((m) => m.id == deletedId ? m.asDeleted() : m)
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
    String? parentMessageId,
  }) async {
    final message = await _service.sendPersonalMessage(
      arg,
      body,
      imageUrl: imageUrl,
      imageMimeType: imageMimeType,
      imageSize: imageSize,
      imageCompressed: imageCompressed,
      parentMessageId: parentMessageId,
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
