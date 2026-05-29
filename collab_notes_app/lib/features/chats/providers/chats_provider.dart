import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/realtime/ws_client.dart';
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
    final ws = ref.read(wsClientProvider);
    _wsSub = ws.events.listen((event) {
      if (event is PersonalMessageEvent) {
        // Простейшая стратегия — рефетч списка. Дёшево и без багов с
        // непрочитанностью.
        refresh();
      }
    });
    ref.onDispose(() => _wsSub?.cancel());
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
    final ws = ref.read(wsClientProvider);
    _wsSub = ws.events.listen((event) {
      if (event is GroupMessageEvent) {
        final data = event.data;
        if (data['groupId'] != arg.groupId) return;
        // Если открыт note-chat — показываем только сообщения с этой noteId
        if (arg.noteId != null && data['noteId'] != arg.noteId) return;
        try {
          final message = GroupChatMessage.fromJson(data);
          // Префикс — новое сообщение поверх (мы рендерим reverse=true)
          state = state.whenData((list) => [message, ...list]);
        } catch (_) {}
      }
    });
    ref.onDispose(() => _wsSub?.cancel());
    return _service.getGroupMessages(arg.groupId, noteId: arg.noteId);
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

  @override
  Future<List<PersonalChatMessage>> build(String otherUserId) async {
    final ws = ref.read(wsClientProvider);
    _wsSub = ws.events.listen((event) {
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
        } catch (_) {}
      }
    });
    ref.onDispose(() => _wsSub?.cancel());
    return _service.getPersonalMessages(otherUserId);
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
    } catch (_) {}
  }
}
