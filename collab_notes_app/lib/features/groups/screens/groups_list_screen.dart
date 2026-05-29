import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';
import '../providers/groups_provider.dart';
import '../widgets/create_group_sheet.dart';
import '../../../shared/theme/app_dimensions.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../shared/widgets/group_avatar.dart';

class GroupsListScreen extends ConsumerWidget {
  const GroupsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Группы'),
        actions: [
          IconButton(
            icon: const Icon(SolarIconsOutline.refresh),
            onPressed: () => ref.read(groupsProvider.notifier).refresh(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(SolarIconsBold.addCircle),
        label: const Text('Новая группа'),
        onPressed: () => _openCreateSheet(context),
      ),
      body: groupsAsync.when(
        loading: () => const AppLoader(),
        error: (err, _) => AppErrorState(
          message: 'Не удалось загрузить группы',
          onRetry: () => ref.read(groupsProvider.notifier).refresh(),
        ),
        data: (groups) {
          if (groups.isEmpty) {
            return const AppEmptyState(
              icon: SolarIconsOutline.usersGroupRounded,
              message: 'Нет групп',
              hint: 'Создайте первую группу или примите приглашение',
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(groupsProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xxxl * 2,
              ),
              itemCount: groups.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final group = groups[index];
                return _GroupTile(
                  title: group.title,
                  membersCount: group.members.length,
                  onTap: () => context.push('/groups/${group.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _openCreateSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const CreateGroupSheet(),
    );
  }
}

class _GroupTile extends StatelessWidget {
  final String title;
  final int membersCount;
  final VoidCallback onTap;

  const _GroupTile({
    required this.title,
    required this.membersCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              GroupAvatar(title: title),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _membersLabel(membersCount),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(SolarIconsOutline.altArrowRight, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }

  static String _membersLabel(int n) {
    if (n % 10 == 1 && n % 100 != 11) return '$n участник';
    if ([2, 3, 4].contains(n % 10) && ![12, 13, 14].contains(n % 100)) {
      return '$n участника';
    }
    return '$n участников';
  }
}
