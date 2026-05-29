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

  String get url {
    // Convert local path to public URL
    final filename = path.split('/').last;
    return '${_baseUrl}/uploads/notes/$filename';
  }

  static String _baseUrl = '';
  static void setBaseUrl(String url) => _baseUrl = url;
}

class NoteModel {
  final String id;
  final String groupId;
  final String title;
  final String content;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, String> creator;
  final List<ChecklistItem> checklistItems;
  final List<NoteImage> images;

  const NoteModel({
    required this.id,
    required this.groupId,
    required this.title,
    required this.content,
    required this.archived,
    required this.createdAt,
    required this.updatedAt,
    required this.creator,
    required this.checklistItems,
    required this.images,
  });

  factory NoteModel.fromJson(Map<String, dynamic> json) => NoteModel(
        id: json['id'] as String,
        groupId: json['groupId'] as String,
        title: json['title'] as String,
        content: json['content'] as String? ?? '',
        archived: json['archived'] as bool? ?? false,
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
