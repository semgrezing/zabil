enum ActivityType {
  noteCreated,
  noteUpdated,
  messageSent,
  memberJoined,
}

class ActivityItem {
  final String id;
  final ActivityType type;
  final String actorId;
  final String actorName;
  final String? actorAvatar;
  final String groupId;
  final String groupTitle;
  final String targetId;
  final String? targetTitle;
  final DateTime createdAt;

  const ActivityItem({
    required this.id,
    required this.type,
    required this.actorId,
    required this.actorName,
    required this.actorAvatar,
    required this.groupId,
    required this.groupTitle,
    required this.targetId,
    required this.targetTitle,
    required this.createdAt,
  });

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    return ActivityItem(
      id: json['id'] as String,
      type: _parseType(json['type'] as String),
      actorId: json['actorId'] as String,
      actorName: json['actorName'] as String,
      actorAvatar: json['actorAvatar'] as String?,
      groupId: json['groupId'] as String,
      groupTitle: json['groupTitle'] as String,
      targetId: json['targetId'] as String,
      targetTitle: json['targetTitle'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static ActivityType _parseType(String raw) {
    switch (raw) {
      case 'note_created': return ActivityType.noteCreated;
      case 'note_updated': return ActivityType.noteUpdated;
      case 'message_sent': return ActivityType.messageSent;
      case 'member_joined': return ActivityType.memberJoined;
      default: return ActivityType.noteUpdated;
    }
  }
}
