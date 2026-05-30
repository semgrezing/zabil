import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';

/// Data class for a user currently viewing a note.
class NoteViewer {
  final String userId;
  final String displayName;

  const NoteViewer({required this.userId, required this.displayName});
}

/// Shows avatars of users currently viewing this note.
/// Each avatar slides in from the right with a spring animation.
class NotePresenceBar extends StatelessWidget {
  final List<NoteViewer> viewers;

  const NotePresenceBar({super.key, required this.viewers});

  static const _avatarColors = [
    Color(0xFF4DABF7),
    Color(0xFF69DB7C),
    Color(0xFF9775FA),
    Color(0xFFF783AC),
  ];

  static const double _avatarSize = 24;
  static const double _overlapOffset = 8;

  @override
  Widget build(BuildContext context) {
    if (viewers.isEmpty) return const SizedBox.shrink();

    final stackWidth =
        _avatarSize + (_avatarSize - _overlapOffset) * (viewers.length - 1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: stackWidth,
            height: _avatarSize,
            child: Stack(
              children: [
                for (int i = 0; i < viewers.length; i++)
                  Positioned(
                    left: i * (_avatarSize - _overlapOffset),
                    child: _buildAvatar(viewers[i], i),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            viewers.length == 1 ? 'просматривает' : 'просматривают',
            style: const TextStyle(
              color: AppColors.fgSoft,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(NoteViewer viewer, int index) {
    final color = _avatarColors[index % _avatarColors.length];
    final initial = viewer.displayName.isNotEmpty
        ? viewer.displayName[0].toUpperCase()
        : '?';

    return CircleAvatar(
      radius: _avatarSize / 2,
      backgroundColor: color,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: 50 * index))
        .slideX(begin: 0.3, end: 0)
        .fadeIn();
  }
}
