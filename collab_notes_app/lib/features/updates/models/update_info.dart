/// Информация о доступном обновлении — ответ `/update`.
class UpdateInfo {
  final bool hasUpdate;
  final String latestVersion;
  final String? downloadUrl;
  final String? manifestUrl;
  final String? sha256;
  final int? fileSize;
  final bool mandatory;
  final String? notes;

  const UpdateInfo({
    required this.hasUpdate,
    required this.latestVersion,
    this.downloadUrl,
    this.manifestUrl,
    this.sha256,
    this.fileSize,
    this.mandatory = false,
    this.notes,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) => UpdateInfo(
        hasUpdate: json['hasUpdate'] as bool? ?? false,
        latestVersion: json['latestVersion'] as String? ?? '',
        downloadUrl: json['downloadUrl'] as String?,
        manifestUrl: json['manifestUrl'] as String?,
        sha256: json['sha256'] as String?,
        fileSize: json['fileSize'] as int?,
        mandatory: json['mandatory'] as bool? ?? false,
        notes: json['notes'] as String?,
      );

  /// Чистая инфа когда обновлений нет.
  factory UpdateInfo.none(String currentVersion) => UpdateInfo(
        hasUpdate: false,
        latestVersion: currentVersion,
      );
}
