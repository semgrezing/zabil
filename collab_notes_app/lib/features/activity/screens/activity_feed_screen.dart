import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';
import '../models/activity_item.dart';
import '../providers/activity_provider.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_dimensions.dart';
import '../../../shared/widgets/app_loader.dart';

class ActivityFeedScreen extends ConsumerWidget {
  const ActivityFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(activityFeedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Активность'),
        actions: [
          IconButton(
            icon: const Icon(SolarIconsOutline.refresh),
            tooltip: 'Обновить',
            onPressed: () => ref.read(activityFeedProvider.notifier).refresh(),
          ),
        ],
      ),
      body: feedAsync.when(
        loading: () => const AppLoader(),
        error: (err, _) => Center(child: Text('Ошибка: $err')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    SolarIconsOutline.clockCircle,
                    size: 48,
                    color: AppColors.fgSoft.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Активность за последние 30 дней не найдена',
                    style: TextStyle(color: AppColors.fgSoft),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(activityFeedProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
                horizontal: AppSpacing.lg,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) => _ActivityTile(
                item: items[index],
                onTap: () => _navigate(context, items[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  void _navigate(BuildContext context, ActivityItem item) {
    switch (item.type) {
      case ActivityType.noteCreated:
      case ActivityType.noteUpdated:
        context.push('/notes/${item.targetId}');
      case ActivityType.messageSent:
        context.push(
          '/chats/group/${item.groupId}',
          extra: {'title': item.groupTitle},
        );
      case ActivityType.memberJoined:
        break;
    }
  }
}

class _ActivityTile extends StatelessWidget {
  final ActivityItem item;
  final VoidCallback? onTap;

  const _ActivityTile({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Avatar(name: item.actorName, avatarUrl: item.actorAvatar),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 14,
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(
                          text: item.actorName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: ' ${_actionText(item.type)} '),
                        if (item.targetTitle != null)
                          TextSpan(
                            text: '"${item.targetTitle}"',
                            style: const TextStyle(color: AppColors.fgSoft),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        SolarIconsOutline.usersGroupRounded,
                        size: 12,
                        color: AppColors.fgSoft,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.groupTitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.fgSoft,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        _formatTime(item.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.fgSoft,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              _typeIcon(item.type),
              size: 16,
              color: _typeColor(item.type),
            ),
          ],
        ),
      ),
    );
  }

  String _actionText(ActivityType type) {
    switch (type) {
      case ActivityType.noteCreated: return 'создал(а) заметку';
      case ActivityType.noteUpdated: return 'обновил(а) заметку';
      case ActivityType.messageSent: return 'написал(а)';
      case ActivityType.memberJoined: return 'присоединился(лась) к группе';
    }
  }

  IconData _typeIcon(ActivityType type) {
    switch (type) {
      case ActivityType.noteCreated: return SolarIconsOutline.notesMinimalistic;
      case ActivityType.noteUpdated: return SolarIconsOutline.pen2;
      case ActivityType.messageSent: return SolarIconsOutline.chatRound;
      case ActivityType.memberJoined: return SolarIconsOutline.addCircle;
    }
  }

  Color _typeColor(ActivityType type) {
    switch (type) {
      case ActivityType.noteCreated: return AppColors.success;
      case ActivityType.noteUpdated: return AppColors.warning;
      case ActivityType.messageSent: return const Color(0xFF4DABF7);
      case ActivityType.memberJoined: return const Color(0xFF9775FA);
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин.';
    if (diff.inHours < 24) return '${diff.inHours} ч.';
    if (diff.inDays < 7) return '${diff.inDays} дн.';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}';
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;

  const _Avatar({required this.name, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.bg3,
      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
      child: avatarUrl == null
          ? Text(
              initials,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
    );
  }
}
