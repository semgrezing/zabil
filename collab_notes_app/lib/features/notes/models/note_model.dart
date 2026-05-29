import '../../../core/config/app_config.dart';

class ChecklistItem {
  final String id;
  final String noteId;
  final String text;
  final bool completed;
  final int position;

  const ChecklistItem({
    required this.id,
    required this.noteId,
    required this.text,
    required this.completed,
    required this.position,
  });

  factory ChecklistItem.fromJson(Map<String, dynamic> json) => ChecklistItem(
        id: json['id'] as String,
        noteId: json['noteId'] as String,
        text: json['text'] as String,
        completed: json['completed'] as bool,
        position: json['position'] as int,
      );
}

class NoteImage {
  final String id;
  final String noteId;
  final String filename;
  final String path;

  const NoteImage({
    required this.id,
    required this.noteId,
    required this.filename,
    required this.path,
  });

  factory NoteImage.fromJson(Map<String, dynamic> json) => NoteImage(
        id: json['id'] as String,
        noteId: json['noteId'] as String,
        filename: json['filename'] as String,
        path: json['path'] as String,
      );

  /// Public URL для статики бэкенда.
  ///
  /// Backend хранит файлы в `<UPLOADS_PATH>/notes/<uuid>.webp` и сервит их
  /// статически по `<origin>/uploads/notes/<filename>` без авторизации.
  /// Используем `apiOrigin` (без `/api/v1`), потому что статика смонтирована
  /// в корень, а API — под `/api/v1`.
  String get url {
    final f = filename.isNotEmpty ? filename : path.split(RegExp(r'[\\/]')).last;
    return '${AppConfig.apiOrigin}/uploads/notes/$f';
  }
}

class NoteModel {
  final String id;
  final String groupId;
  final String? groupTitle;
  final bool isPersonal;
  final String title;
  final String content;
  final String? colorLabel;
  final bool archived;
  final bool pinned;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, String> creator;
  final List<ChecklistItem> checklistItems;
  final List<NoteImage> images;

  const NoteModel({
    required this.id,
    required this.groupId,
    required this.groupTitle,
    required this.isPersonal,
    required this.title,
    required this.content,
    required this.colorLabel,
    required this.archived,
    required this.pinned,
    required this.createdAt,
    required this.updatedAt,
    required this.creator,
    required this.checklistItems,
    required this.images,
  });

  factory NoteModel.fromJson(Map<String, dynamic> json) => NoteModel(
        id: json['id'] as String,
        groupId: json['groupId'] as String,
      groupTitle: (json['group'] as Map<String, dynamic>?)?['title'] as String?,
      isPersonal: ((json['group'] as Map<String, dynamic>?)?['isPersonal'] as bool?) ?? false,
        title: json['title'] as String,
        content: json['content'] as String? ?? '',
      colorLabel: json['colorLabel'] as String?,
        archived: json['archived'] as bool? ?? false,
        pinned: json['pinned'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        creator: Map<String, String>.from(
          (json['creator'] as Map?)
            ?.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')) ??
              {},
        ),
        checklistItems: (json['checklistItems'] as List<dynamic>? ?? [])
            .map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        images: (json['images'] as List<dynamic>? ?? [])
            .map((e) => NoteImage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
