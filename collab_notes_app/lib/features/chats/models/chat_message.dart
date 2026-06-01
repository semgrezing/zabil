/// Quoted parent message for replies.
class ReplyPreview {
  final String id;
  final String senderId;
  final String senderName;
  final String body;

  const ReplyPreview({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.body,
  });

  factory ReplyPreview.fromJson(Map<String, dynamic> json, {String? fallbackSenderName}) {
    final sender = json['sender'] as Map?;
    return ReplyPreview(
      id: json['id'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderName: sender != null ? _extractDisplayName(sender) : (fallbackSenderName ?? '?'),
      body: json['body'] as String? ?? '',
    );
  }

  static String _extractDisplayName(Map? sender) {
    if (sender == null) return '?';
    final name = sender['displayName']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    return sender['username']?.toString() ?? '?';
  }
}

/// Сообщение в групповом чате (потенциально привязано к заметке).
class GroupChatMessage {
  final String id;
  final String groupId;
  final String senderId;
  final Map<String, String> sender;
  final String? noteId;
  final String? noteTitle;
  final String? noteColorLabel;
  final String body;
  final String? imageUrl;
  final String? imageMimeType;
  final int? imageSize;
  final bool? imageCompressed;
  final DateTime? deletedAt;
  final DateTime createdAt;
  /// Number of group members (excluding sender) who have read this message.
  final int readCount;
  /// Whether the current viewer has read this message.
  final bool isReadByMe;
  /// Parent message for replies.
  final ReplyPreview? replyTo;

  bool get isDeleted => deletedAt != null;

  const GroupChatMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.sender,
    required this.noteId,
    required this.noteTitle,
    required this.noteColorLabel,
    required this.body,
    required this.imageUrl,
    required this.imageMimeType,
    required this.imageSize,
    required this.imageCompressed,
    this.deletedAt,
    required this.createdAt,
    this.readCount = 0,
    this.isReadByMe = false,
    this.replyTo,
  });

  GroupChatMessage asDeleted() => GroupChatMessage(
    id: id, groupId: groupId, senderId: senderId, sender: sender,
    noteId: noteId, noteTitle: noteTitle, noteColorLabel: noteColorLabel,
    body: '', imageUrl: null, imageMimeType: null, imageSize: null,
    imageCompressed: null, deletedAt: DateTime.now(), createdAt: createdAt,
  );

  factory GroupChatMessage.fromJson(Map<String, dynamic> json) => GroupChatMessage(
        id: json['id'] as String,
        groupId: json['groupId'] as String,
        senderId: json['senderId'] as String,
        sender: Map<String, String>.from(
            (json['sender'] as Map?)?.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')) ?? {}),
        noteId: json['noteId'] as String?,
        noteTitle: (json['note'] as Map<String, dynamic>?)?['title'] as String?,
        noteColorLabel: (json['note'] as Map<String, dynamic>?)?['colorLabel'] as String?,
        body: json['body'] as String,
        imageUrl: json['imageUrl'] as String?,
        imageMimeType: json['imageMimeType'] as String?,
        imageSize: (json['imageSize'] as num?)?.toInt(),
        imageCompressed: json['imageCompressed'] as bool?,
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.now(),
        readCount: (json['readCount'] as num?)?.toInt() ?? 0,
        isReadByMe: json['isReadByMe'] as bool? ?? false,
        replyTo: json['parentMessage'] is Map<String, dynamic>
            ? ReplyPreview.fromJson(json['parentMessage'] as Map<String, dynamic>)
            : null,
      );

  GroupChatMessage copyWith({
    int? readCount,
    bool? isReadByMe,
  }) {
    return GroupChatMessage(
      id: id,
      groupId: groupId,
      senderId: senderId,
      sender: sender,
      noteId: noteId,
      noteTitle: noteTitle,
      noteColorLabel: noteColorLabel,
      body: body,
      imageUrl: imageUrl,
      imageMimeType: imageMimeType,
      imageSize: imageSize,
      imageCompressed: imageCompressed,
      createdAt: createdAt,
      readCount: readCount ?? this.readCount,
      isReadByMe: isReadByMe ?? this.isReadByMe,
      replyTo: replyTo,
    );
  }
}

/// Личное 1:1 сообщение.
class PersonalChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String body;
  final String? imageUrl;
  final String? imageMimeType;
  final int? imageSize;
  final bool? imageCompressed;
  final DateTime? readAt;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final ReplyPreview? replyTo;

  bool get isDeleted => deletedAt != null;

  const PersonalChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.body,
    required this.imageUrl,
    required this.imageMimeType,
    required this.imageSize,
    required this.imageCompressed,
    required this.readAt,
    this.deletedAt,
    required this.createdAt,
    this.replyTo,
  });

  PersonalChatMessage asDeleted() => PersonalChatMessage(
    id: id, senderId: senderId, receiverId: receiverId,
    body: '', imageUrl: null, imageMimeType: null, imageSize: null,
    imageCompressed: null, readAt: readAt, deletedAt: DateTime.now(),
    createdAt: createdAt,
  );

  factory PersonalChatMessage.fromJson(Map<String, dynamic> json) => PersonalChatMessage(
        id: json['id'] as String,
        senderId: json['senderId'] as String,
        receiverId: json['receiverId'] as String,
        body: json['body'] as String,
        imageUrl: json['imageUrl'] as String?,
        imageMimeType: json['imageMimeType'] as String?,
        imageSize: (json['imageSize'] as num?)?.toInt(),
        imageCompressed: json['imageCompressed'] as bool?,
        readAt: DateTime.tryParse(json['readAt']?.toString() ?? ''),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.now(),
        replyTo: json['parentMessage'] is Map<String, dynamic>
            ? ReplyPreview.fromJson(json['parentMessage'] as Map<String, dynamic>)
            : null,
      );

  PersonalChatMessage copyWith({
    DateTime? readAt,
  }) {
    return PersonalChatMessage(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      body: body,
      imageUrl: imageUrl,
      imageMimeType: imageMimeType,
      imageSize: imageSize,
      imageCompressed: imageCompressed,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
      replyTo: replyTo,
    );
  }
}

/// Превью личного чата (последнее сообщение + unread count).
class PersonalChatPreview {
  final Map<String, String> user;
  final PersonalChatMessage lastMessage;
  final int unreadCount;

  const PersonalChatPreview({
    required this.user,
    required this.lastMessage,
    required this.unreadCount,
  });

  factory PersonalChatPreview.fromJson(Map<String, dynamic> json) => PersonalChatPreview(
        user: Map<String, String>.from(
            (json['user'] as Map?)?.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')) ?? {}),
        lastMessage: json['lastMessage'] is Map<String, dynamic>
            ? PersonalChatMessage.fromJson(
                json['lastMessage'] as Map<String, dynamic>,
              )
            : PersonalChatMessage(
                id: '',
                senderId: '',
                receiverId: '',
                body: '',
                imageUrl: null,
                imageMimeType: null,
                imageSize: null,
                imageCompressed: null,
                readAt: null,
                createdAt: DateTime.now(),
              ),
        unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      );

  bool get isOnline => user['isOnline'] == 'true';

  DateTime? get lastSeenAt {
    final raw = user['lastSeenAt'];
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  PersonalChatPreview copyWithPresence({
    required bool isOnline,
    DateTime? lastSeenAt,
  }) {
    return PersonalChatPreview(
      user: {
        ...user,
        'isOnline': isOnline.toString(),
        'lastSeenAt': lastSeenAt?.toIso8601String() ?? '',
      },
      lastMessage: lastMessage,
      unreadCount: unreadCount,
    );
  }

  PersonalChatPreview copyWith({
    Map<String, String>? user,
    PersonalChatMessage? lastMessage,
    int? unreadCount,
  }) {
    return PersonalChatPreview(
      user: user ?? this.user,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
