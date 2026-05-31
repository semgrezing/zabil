class GroupMemberModel {
  final String id;
  final String userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final DateTime? lastSeenAt;
  final bool isOnline;
  final String role;

  const GroupMemberModel({
    required this.id,
    required this.userId,
    required this.username,
    required this.role,
    this.displayName,
    this.avatarUrl,
    this.lastSeenAt,
    this.isOnline = false,
  });

  String get displayLabel {
    final name = displayName?.trim();
    return name != null && name.isNotEmpty ? name : username;
  }

  GroupMemberModel copyWithPresence({
    required bool isOnline,
    DateTime? lastSeenAt,
  }) {
    return GroupMemberModel(
      id: id,
      userId: userId,
      username: username,
      role: role,
      displayName: displayName,
      avatarUrl: avatarUrl,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      isOnline: isOnline,
    );
  }

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? {};
    final lastSeenAt = user['lastSeenAt'] != null
        ? DateTime.tryParse(user['lastSeenAt'].toString())
        : null;
    return GroupMemberModel(
      id: json['id'] as String,
      userId: user['id'] as String? ?? '',
      username: user['username'] as String? ?? '',
      displayName: user['displayName'] as String?,
      avatarUrl: user['avatarUrl'] as String?,
      lastSeenAt: lastSeenAt,
      isOnline: _computeOnline(lastSeenAt),
      role: json['role'] as String? ?? 'member',
    );
  }
}

class GroupLastMessageSenderModel {
  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;

  const GroupLastMessageSenderModel({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
  });

  String get displayLabel {
    final name = displayName?.trim();
    return name != null && name.isNotEmpty ? name : username;
  }

  factory GroupLastMessageSenderModel.fromJson(Map<String, dynamic> json) {
    return GroupLastMessageSenderModel(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

bool _computeOnline(DateTime? lastSeenAt) {
  if (lastSeenAt == null) return false;
  return DateTime.now().difference(lastSeenAt.toLocal()).inMinutes < 3;
}

class GroupLastMessageModel {
  final String id;
  final String body;
  final String? imageUrl;
  final DateTime? createdAt;
  final GroupLastMessageSenderModel sender;

  const GroupLastMessageModel({
    required this.id,
    required this.body,
    required this.imageUrl,
    required this.createdAt,
    required this.sender,
  });

  bool get hasImage {
    final value = imageUrl?.trim();
    return value != null && value.isNotEmpty;
  }

  String get previewText {
    final text = body.trim();
    if (text.isNotEmpty) return text;
    if (hasImage) return 'Фото';
    return 'Новое сообщение';
  }

  factory GroupLastMessageModel.fromJson(Map<String, dynamic> json) {
    return GroupLastMessageModel(
      id: json['id'] as String? ?? '',
      body: json['body'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      sender: GroupLastMessageSenderModel.fromJson(
        (json['sender'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }
}

class GroupModel {
  final String id;
  final String title;
  final String? avatarUrl;
  final bool isPersonal;
  final List<GroupMemberModel> members;
  final GroupLastMessageModel? lastMessage;
  // TODO(B17): Backend should add unreadCount to buildGroupPayload
  // (COUNT of messages where user is not in reads array).
  // For now defaults to 0 — badge will show once backend support is added.
  final int unreadCount;

  const GroupModel({
    required this.id,
    required this.title,
    required this.avatarUrl,
    required this.isPersonal,
    required this.members,
    required this.lastMessage,
    this.unreadCount = 0,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) => GroupModel(
        id: json['id'] as String,
        title: json['title'] as String,
        avatarUrl: json['avatarUrl'] as String?,
        isPersonal: json['isPersonal'] as bool? ?? false,
        members: (json['members'] as List<dynamic>? ?? [])
            .map((e) => GroupMemberModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        lastMessage: json['lastMessage'] is Map<String, dynamic>
            ? GroupLastMessageModel.fromJson(json['lastMessage'] as Map<String, dynamic>)
            : null,
        unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      );
}
