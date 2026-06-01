class MentionModel {
  final String id;
  final String context; // 'group_message' | 'personal_message' | 'note'
  final Map<String, dynamic> mentioner;
  final Map<String, String>? group;
  final Map<String, String>? note;
  final String? messageId;
  final bool read;
  final DateTime createdAt;

  const MentionModel({
    required this.id,
    required this.context,
    required this.mentioner,
    this.group,
    this.note,
    this.messageId,
    required this.read,
    required this.createdAt,
  });

  factory MentionModel.fromJson(Map<String, dynamic> json) => MentionModel(
        id: json['id'] as String,
        context: json['context'] as String,
        mentioner: (json['mentioner'] as Map?)?.cast<String, dynamic>() ?? {},
        group: json['group'] != null
            ? (json['group'] as Map).cast<String, String>()
            : null,
        note: json['note'] != null
            ? (json['note'] as Map).cast<String, String>()
            : null,
        messageId: json['messageId'] as String?,
        read: json['read'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  String get mentionerLabel {
    final d = mentioner['displayName']?.toString().trim();
    if (d != null && d.isNotEmpty) return d;
    return mentioner['username']?.toString() ?? 'Кто-то';
  }

  String get contextLabel {
    if (context == 'note' && note != null) return 'в заметке «${note!['title'] ?? ''}»';
    if (context == 'group_message' && group != null) return 'в «${group!['title'] ?? ''}»';
    if (context == 'personal_message') return 'в личном сообщении';
    return '';
  }

  String? get navigatePath {
    if (context == 'note' && note != null) return '/notes/${note!['id']}';
    if (context == 'group_message' && group != null) {
      return '/chats/group/${group!['id']}';
    }
    if (context == 'personal_message') {
      final mentionerId = mentioner['id']?.toString();
      if (mentionerId != null) return '/chats/personal/$mentionerId';
    }
    return null;
  }
}
