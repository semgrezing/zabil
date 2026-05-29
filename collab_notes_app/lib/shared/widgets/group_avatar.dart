import 'package:flutter/material.dart';
import '../theme/app_typography.dart';

/// Унифицированный аватар группы — кружок с первой буквой названия.
/// Используется в списках групп, на экране деталей, в поиске.
class GroupAvatar extends StatelessWidget {
  final String title;
  final double radius;

  const GroupAvatar({super.key, required this.title, this.radius = 22});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final letter = title.isNotEmpty ? title[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: cs.surfaceContainerHighest,
      child: Text(
        letter,
        style: AppTypography.titleMedium.copyWith(color: cs.onSurface),
      ),
    );
  }
}
