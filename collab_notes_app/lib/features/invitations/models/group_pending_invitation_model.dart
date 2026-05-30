class GroupPendingInvitationModel {
  final String id;
  final Map<String, String> sender;
  final Map<String, String> receiver;
  final DateTime createdAt;

  const GroupPendingInvitationModel({
    required this.id,
    required this.sender,
    required this.receiver,
    required this.createdAt,
  });

  factory GroupPendingInvitationModel.fromJson(Map<String, dynamic> json) {
    return GroupPendingInvitationModel(
      id: json['id'] as String,
      sender: Map<String, String>.from(
        (json['sender'] as Map?)
                ?.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')) ??
            {},
      ),
      receiver: Map<String, String>.from(
        (json['receiver'] as Map?)
                ?.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')) ??
            {},
      ),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  String get senderLabel {
    final displayName = sender['displayName']?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    return sender['username'] ?? '?';
  }

  String get receiverLabel {
    final displayName = receiver['displayName']?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    return receiver['username'] ?? '?';
  }
}