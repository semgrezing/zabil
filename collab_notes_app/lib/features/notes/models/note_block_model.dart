import 'dart:convert';
import '../../../core/config/app_config.dart';

enum NoteBlockType { text, checklist, image, divider }

NoteBlockType noteBlockTypeFromString(String s) {
  switch (s) {
    case 'text':
      return NoteBlockType.text;
    case 'checklist':
      return NoteBlockType.checklist;
    case 'image':
      return NoteBlockType.image;
    case 'divider':
      return NoteBlockType.divider;
    default:
      return NoteBlockType.text;
  }
}

class NoteBlockModel {
  final String id;
  final String noteId;
  final NoteBlockType type;
  final String content;
  final int position;
  final DateTime updatedAt;

  const NoteBlockModel({
    required this.id,
    required this.noteId,
    required this.type,
    required this.content,
    required this.position,
    required this.updatedAt,
  });

  NoteBlockModel copyWith({
    String? content,
    int? position,
  }) =>
      NoteBlockModel(
        id: id,
        noteId: noteId,
        type: type,
        content: content ?? this.content,
        position: position ?? this.position,
        updatedAt: DateTime.now(),
      );

  Map<String, dynamic> get _parsed {
    try {
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  List<dynamic> get deltaOps {
    final p = _parsed;
    return (p['delta'] as List<dynamic>?) ?? [{'insert': '\n'}];
  }

  List<ChecklistBlockItem> get checklistItems {
    final p = _parsed;
    final items = p['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => ChecklistBlockItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  NoteBlockImageData? get imageData {
    if (type != NoteBlockType.image) return null;
    final p = _parsed;
    if (p.isEmpty) return null;
    return NoteBlockImageData.fromJson(p);
  }

  factory NoteBlockModel.fromJson(Map<String, dynamic> json) => NoteBlockModel(
        id: json['id'] as String,
        noteId: json['noteId'] as String,
        type: noteBlockTypeFromString(json['type'] as String),
        content: json['content'] as String? ?? '{}',
        position: json['position'] as int,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

class ChecklistBlockItem {
  final String id;
  final String text;
  final bool completed;

  const ChecklistBlockItem({
    required this.id,
    required this.text,
    required this.completed,
  });

  ChecklistBlockItem copyWith({String? text, bool? completed}) =>
      ChecklistBlockItem(
        id: id,
        text: text ?? this.text,
        completed: completed ?? this.completed,
      );

  factory ChecklistBlockItem.fromJson(Map<String, dynamic> json) =>
      ChecklistBlockItem(
        id: json['id'] as String,
        text: json['text'] as String,
        completed: json['completed'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'completed': completed,
      };
}

class NoteBlockImageData {
  final String imageId;
  final String filename;
  final String path;
  final String? originalName;
  final String? mimeType;
  final int? fileSize;

  const NoteBlockImageData({
    required this.imageId,
    required this.filename,
    required this.path,
    this.originalName,
    this.mimeType,
    this.fileSize,
  });

  String get url {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    if (path.startsWith('/uploads/')) return '${AppConfig.apiOrigin}$path';
    return '${AppConfig.apiOrigin}/uploads/notes/$filename';
  }

  factory NoteBlockImageData.fromJson(Map<String, dynamic> json) =>
      NoteBlockImageData(
        imageId: json['imageId'] as String,
        filename: json['filename'] as String? ?? '',
        path: json['path'] as String? ?? '',
        originalName: json['originalName'] as String?,
        mimeType: json['mimeType'] as String?,
        fileSize: json['fileSize'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'imageId': imageId,
        'filename': filename,
        'path': path,
        if (originalName != null) 'originalName': originalName,
        if (mimeType != null) 'mimeType': mimeType,
        if (fileSize != null) 'fileSize': fileSize,
      };
}
