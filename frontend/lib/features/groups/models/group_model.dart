class GroupMemberModel {
  final String id;
  final String userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String role;

  const GroupMemberModel({
    required this.id,
    required this.userId,
    required this.username,
    required this.role,
    this.displayName,
    this.avatarUrl,
  });

  String get displayLabel {
    final name = displayName?.trim();
    return name != null && name.isNotEmpty ? name : username;
  }

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? {};
    return GroupMemberModel(
      id: json['id'] as String,
      userId: user['id'] as String? ?? '',
      username: user['username'] as String? ?? '',
      displayName: user['displayName'] as String?,
      avatarUrl: user['avatarUrl'] as String?,
      role: json['role'] as String? ?? 'member',
    );
  }
}

class GroupModel {
  final String id;
  final String title;
  final List<GroupMemberModel> members;

  const GroupModel({
    required this.id,
    required this.title,
    required this.members,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) => GroupModel(
        id: json['id'] as String,
        title: json['title'] as String,
        members: (json['members'] as List<dynamic>? ?? [])
            .map((e) => GroupMemberModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
