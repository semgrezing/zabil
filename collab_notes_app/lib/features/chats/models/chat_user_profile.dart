class ChatUserAvatarHistoryItem {
  final String id;
  final String avatarUrl;
  final DateTime createdAt;

  const ChatUserAvatarHistoryItem({
    required this.id,
    required this.avatarUrl,
    required this.createdAt,
  });

  factory ChatUserAvatarHistoryItem.fromJson(Map<String, dynamic> json) {
    return ChatUserAvatarHistoryItem(
      id: json['id'] as String,
      avatarUrl: json['avatarUrl'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class ChatUserCommonGroup {
  final String id;
  final String title;
  final String? avatarUrl;
  final int membersCount;

  const ChatUserCommonGroup({
    required this.id,
    required this.title,
    required this.avatarUrl,
    required this.membersCount,
  });

  factory ChatUserCommonGroup.fromJson(Map<String, dynamic> json) {
    return ChatUserCommonGroup(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Группа',
      avatarUrl: json['avatarUrl'] as String?,
      membersCount: (json['membersCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class ChatUserProfile {
  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final DateTime? lastSeenAt;
  final bool isOnline;
  final List<ChatUserAvatarHistoryItem> avatarHistory;
  final List<ChatUserCommonGroup> commonGroups;

  const ChatUserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    this.lastSeenAt,
    this.isOnline = false,
    required this.avatarHistory,
    required this.commonGroups,
  });

  String get displayLabel {
    final name = displayName?.trim();
    return name != null && name.isNotEmpty ? name : username;
  }

  factory ChatUserProfile.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ChatUserProfile(
      id: user['id']?.toString() ?? '',
      username: user['username']?.toString() ?? '',
      displayName: user['displayName']?.toString(),
      avatarUrl: user['avatarUrl']?.toString(),
      lastSeenAt: user['lastSeenAt'] != null
          ? DateTime.tryParse(user['lastSeenAt'].toString())
          : null,
      isOnline: user['isOnline'] as bool? ?? false,
      avatarHistory: ((json['avatarHistory'] as List?) ?? const [])
          .map((e) => ChatUserAvatarHistoryItem.fromJson(
              (e as Map).cast<String, dynamic>()))
          .toList(),
      commonGroups: ((json['commonGroups'] as List?) ?? const [])
          .map((e) =>
              ChatUserCommonGroup.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  ChatUserProfile copyWith({
    bool? isOnline,
    DateTime? lastSeenAt,
  }) {
    return ChatUserProfile(
      id: id,
      username: username,
      displayName: displayName,
      avatarUrl: avatarUrl,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      isOnline: isOnline ?? this.isOnline,
      avatarHistory: avatarHistory,
      commonGroups: commonGroups,
    );
  }
}