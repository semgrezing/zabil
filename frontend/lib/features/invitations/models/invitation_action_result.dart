class InvitationActionResult {
  final bool success;
  final String status;
  final bool alreadyProcessed;

  const InvitationActionResult({
    required this.success,
    required this.status,
    required this.alreadyProcessed,
  });

  factory InvitationActionResult.fromJson(
    Map<String, dynamic>? json, {
    required String fallbackStatus,
  }) {
    if (json == null) {
      return InvitationActionResult(
        success: true,
        status: fallbackStatus,
        alreadyProcessed: false,
      );
    }

    return InvitationActionResult(
      success: json['success'] as bool? ?? true,
      status: json['status'] as String? ?? fallbackStatus,
      alreadyProcessed: json['alreadyProcessed'] as bool? ?? false,
    );
  }
}
