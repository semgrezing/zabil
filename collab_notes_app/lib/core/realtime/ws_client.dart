import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../auth/token_storage.dart';
import '../config/app_config.dart';
import '../notifications/notification_service.dart';
import '../../features/auth/providers/auth_provider.dart';

/// Базовое WS-событие. Sealed-стиль через runtimeType.
abstract class WsEvent {
  const WsEvent();
}

class GroupMessageEvent extends WsEvent {
  final Map<String, dynamic> data;
  const GroupMessageEvent(this.data);
}

class PersonalMessageEvent extends WsEvent {
  final Map<String, dynamic> data;
  const PersonalMessageEvent(this.data);
}

class ChatTypingEvent extends WsEvent {
  final String kind; // 'group' | 'personal'
  final Map<String, dynamic> data;
  const ChatTypingEvent({required this.kind, required this.data});
}

class PersonalReadReceiptEvent extends WsEvent {
  final String readerId;
  final String peerUserId;
  final List<String> messageIds;
  final DateTime readAt;

  const PersonalReadReceiptEvent({
    required this.readerId,
    required this.peerUserId,
    required this.messageIds,
    required this.readAt,
  });
}

class PushNotificationEvent extends WsEvent {
  final String title;
  final String body;
  final Map<String, dynamic> data;
  const PushNotificationEvent({
    required this.title,
    required this.body,
    required this.data,
  });
}

class WsHelloEvent extends WsEvent {
  final String userId;
  const WsHelloEvent(this.userId);
}

class NotePresenceEvent extends WsEvent {
  final String noteId;
  final String userId;
  final String displayName;
  final String action; // 'join' | 'leave'
  const NotePresenceEvent({
    required this.noteId,
    required this.userId,
    required this.displayName,
    required this.action,
  });
}

class NoteTypingEvent extends WsEvent {
  final String noteId;
  final String userId;
  const NoteTypingEvent({required this.noteId, required this.userId});
}

/// WebSocket-клиент с auto-reconnect.
///
/// Подключается на auth (есть валидный access token), переподключается при
/// падении (3 → 6 → 12 → 24 → 30 сек, экспоненциальный backoff с потолком).
/// Эмитит все события через [events] стрим, подписчики фильтруют по типу.
class WsClient {
  WebSocketChannel? _channel;
  StreamSubscription? _channelSub;
  final StreamController<WsEvent> _eventsController =
      StreamController<WsEvent>.broadcast();
  bool _disposed = false;
  bool _connected = false;
  int _retryDelaySec = 3;
  Timer? _retryTimer;

  WsClient();

  Stream<WsEvent> get events => _eventsController.stream;
  bool get isConnected => _connected;

  Future<void> connect() async {
    if (_disposed) return;
    if (_connected) return;

    final token = await TokenStorage().getAccessToken();
    if (token == null) {
      // Нет токена — подождём следующего сигнала об auth
      return;
    }

    // ws/wss URL = origin без /api/v1 + /api/v1/ws
    final origin = AppConfig.apiOrigin;
    final wsScheme = origin.startsWith('https') ? 'wss' : 'ws';
    final host = origin.replaceFirst(RegExp(r'^https?://'), '');
    final url = '$wsScheme://$host/api/v1/ws?token=$token';

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _channelSub = _channel!.stream.listen(
        _onMessage,
        onDone: _onDone,
        onError: _onError,
        cancelOnError: false,
      );
      _connected = true;
      _retryDelaySec = 3; // reset backoff
      debugPrint('[ws] connected $url');
    } catch (e) {
      debugPrint('[ws] connect failed: $e');
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final json = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = json['type'];
      if (type == 'hello') {
        _eventsController.add(WsHelloEvent(json['userId'] as String));
      } else if (type == 'message') {
        final kind = json['kind'];
        final data = json['data'] as Map<String, dynamic>;
        if (kind == 'group') {
          _eventsController.add(GroupMessageEvent(data));
        } else if (kind == 'personal') {
          _eventsController.add(PersonalMessageEvent(data));
        }
      } else if (type == 'notification') {
        final data = json['data'] as Map<String, dynamic>;
        _eventsController.add(PushNotificationEvent(
          title: data['title'] as String? ?? '',
          body: data['body'] as String? ?? '',
          data: data,
        ));
      } else if (type == 'presence') {
        _eventsController.add(NotePresenceEvent(
          noteId: json['noteId'] as String,
          userId: json['userId'] as String,
          displayName: json['displayName'] as String? ?? '',
          action: json['action'] as String,
        ));
      } else if (type == 'typing') {
        _eventsController.add(NoteTypingEvent(
          noteId: json['noteId'] as String,
          userId: json['userId'] as String,
        ));
      } else if (type == 'chat_typing') {
        _eventsController.add(ChatTypingEvent(
          kind: json['kind'] as String? ?? '',
          data: (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
        ));
      } else if (type == 'read_receipt' && json['kind'] == 'personal') {
        final data = (json['data'] as Map?)?.cast<String, dynamic>() ?? const {};
        _eventsController.add(PersonalReadReceiptEvent(
          readerId: data['readerId']?.toString() ?? '',
          peerUserId: data['peerUserId']?.toString() ?? '',
          messageIds: ((data['messageIds'] as List?) ?? const [])
              .map((e) => e.toString())
              .toList(),
          readAt: DateTime.tryParse(data['readAt']?.toString() ?? '') ??
              DateTime.now(),
        ));
      }
    } catch (e) {
      debugPrint('[ws] parse error: $e');
    }
  }

  void _onDone() {
    debugPrint('[ws] closed');
    _connected = false;
    _scheduleReconnect();
  }

  void _onError(Object err) {
    debugPrint('[ws] error: $err');
    _connected = false;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: _retryDelaySec), () {
      _retryDelaySec = (_retryDelaySec * 2).clamp(3, 30);
      connect();
    });
  }

  /// Сообщает серверу, что пользователь открыл/закрыл заметку.
  void sendPresence(String noteId, String action) {
    _send({'type': 'presence', 'noteId': noteId, 'action': action});
  }

  /// Сообщает серверу, что пользователь печатает в заметке.
  void sendTyping(String noteId) {
    _send({'type': 'typing', 'noteId': noteId});
  }

  void sendChatTypingGroup(String groupId) {
    _send({'type': 'chat_typing', 'kind': 'group', 'groupId': groupId});
  }

  void sendChatTypingPersonal(String userId) {
    _send({'type': 'chat_typing', 'kind': 'personal', 'userId': userId});
  }

  void _send(Map<String, dynamic> data) {
    if (!_connected || _channel == null) return;
    try {
      _channel!.sink.add(jsonEncode(data));
    } catch (e) {
      debugPrint('[ws] send error: $e');
    }
  }

  Future<void> disconnect() async {
    _retryTimer?.cancel();
    await _channelSub?.cancel();
    _channelSub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _connected = false;
  }

  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    await _eventsController.close();
  }
}

/// Глобальный singleton WS-клиента. Авто-коннект при появлении auth.
final wsClientProvider = Provider<WsClient>((ref) {
  final client = WsClient();
  // WS → local notifications для платформ без FCM (Windows)
  NotificationService.listenToWsEvents(client);
  // Слушаем auth — реконнект при появлении/смене user
  ref.listen(authStateProvider, (prev, next) {
    final loggedIn = next.valueOrNull?.isLoggedIn ?? false;
    if (loggedIn) {
      client.connect();
    } else {
      client.disconnect();
    }
  });
  // Первичный коннект — если уже залогинены
  Future.microtask(() async {
    final state = ref.read(authStateProvider).valueOrNull;
    if (state?.isLoggedIn ?? false) {
      await client.connect();
    }
  });
  ref.onDispose(() {
    NotificationService.stopWsListener();
    client.dispose();
  });
  return client;
});
