import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Data class for a user currently viewing a note.
class NoteViewer {
  final String userId;
  final String displayName;

  const NoteViewer({required this.userId, required this.displayName});
}

/// Shows names of users currently viewing this note.
class NotePresenceBar extends StatelessWidget {
  final List<NoteViewer> viewers;

  const NotePresenceBar({super.key, required this.viewers});

  @override
  Widget build(BuildContext context) {
    if (viewers.isEmpty) return const SizedBox.shrink();

    final names = viewers.map((v) => v.displayName.trim()).where((n) => n.isNotEmpty).toList();
    final label = names.join(', ');
    final verb = names.length == 1 ? 'просматривает' : 'просматривают';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              '$label $verb',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.fgSoft,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
