class InvitationModel {
  final String id;
  final Map<String, String> group;
  final Map<String, String> sender;
  final String status;
  final DateTime createdAt;

  const InvitationModel({
    required this.id,
    required this.group,
    required this.sender,
    required this.status,
    required this.createdAt,
  });

  factory InvitationModel.fromJson(Map<String, dynamic> json) => InvitationModel(
        id: json['id'] as String,
      group: Map<String, String>.from(
        (json['group'] as Map?)
        ?.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')) ??
        {},
      ),
      sender: Map<String, String>.from(
        (json['sender'] as Map?)
        ?.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')) ??
        {},
      ),
        status: json['status'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
