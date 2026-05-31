import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:solar_icons/solar_icons.dart';
import '../models/group_model.dart';
import '../providers/groups_provider.dart';
import '../widgets/create_group_sheet.dart';
import '../widgets/invite_member_sheet.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_dimensions.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../shared/widgets/group_avatar.dart';

class GroupsListScreen extends ConsumerStatefulWidget {
  const GroupsListScreen({super.key});

  @override
  ConsumerState<GroupsListScreen> createState() => _GroupsListScreenState();
}

class _GroupsListScreenState extends ConsumerState<GroupsListScreen> {
  bool _changingAvatar = false;

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsProvider);
    final currentUserId = ref.watch(authStateProvider).valueOrNull?.user?.id;

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
                final currentMember = currentUserId == null
                    ? null
                    : group.members
                        .where((member) => member.userId == currentUserId)
                        .firstOrNull;
                return _GroupTile(
                  group: group,
                  onTap: () => context.push('/groups/${group.id}'),
                  onLongPress: () => _openGroupActions(
                    context,
                    group,
                    isOwner: currentMember?.role == 'owner',
                    canManage: currentMember?.role == 'owner' ||
                        currentMember?.role == 'admin',
                  ),
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

  Future<void> _openGroupActions(
    BuildContext context,
    GroupModel group, {
    required bool isOwner,
    required bool canManage,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(SolarIconsOutline.usersGroupRounded),
              title: const Text('Список участников'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push('/groups/${group.id}');
              },
            ),
            if (canManage)
              ListTile(
                leading: const Icon(SolarIconsOutline.pen2),
                title: const Text('Изменить название'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _renameGroup(context, group);
                },
              ),
            if (canManage)
              ListTile(
                leading: _changingAvatar
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(SolarIconsOutline.camera),
                title: const Text('Изменить аватарку'),
                onTap: _changingAvatar
                    ? null
                    : () async {
                        Navigator.of(sheetContext).pop();
                        await _changeAvatar(group);
                      },
              ),
            ListTile(
              leading: const Icon(SolarIconsOutline.userPlus),
              title: const Text('Пригласить'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await _openInviteSheet(context, group);
              },
            ),
            ListTile(
              leading: Icon(
                isOwner ? SolarIconsBold.trashBinTrash : SolarIconsBold.logout,
                color: AppColors.negative,
              ),
              title: Text(
                isOwner ? 'Удалить группу' : 'Покинуть группу',
                style: const TextStyle(color: AppColors.negative),
              ),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                if (isOwner) {
                  await _deleteGroup(context, group);
                } else {
                  await _leaveGroup(context, group);
                }
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  Future<void> _renameGroup(BuildContext context, GroupModel group) async {
    final controller = TextEditingController(text: group.title);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Изменить название'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Название группы'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    final nextTitle = controller.text.trim();
    if (ok != true || nextTitle.isEmpty || nextTitle == group.title) return;
    try {
      await ref.read(groupsProvider.notifier).updateGroupTitle(group.id, nextTitle);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Название группы обновлено')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось обновить название: $e')),
      );
    }
  }

  Future<void> _openInviteSheet(BuildContext context, GroupModel group) async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => InviteMemberSheet(groupId: group.id, groupTitle: group.title),
    );
    if (sent == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Приглашение отправлено')),
      );
    }
  }

  Future<void> _changeAvatar(GroupModel group) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressQuality: 100,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Кадрирование аватарки',
          cropStyle: CropStyle.circle,
        ),
        IOSUiSettings(
          title: 'Кадрирование аватарки',
          cropStyle: CropStyle.circle,
        ),
      ],
    );
    if (cropped == null) return;

    setState(() => _changingAvatar = true);
    try {
      await ref.read(groupsProvider.notifier).uploadAvatar(group.id, cropped.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Аватарка группы обновлена')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось обновить аватарку: $e')),
      );
    } finally {
      if (mounted) setState(() => _changingAvatar = false);
    }
  }

  Future<void> _deleteGroup(BuildContext context, GroupModel group) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить группу?'),
        content: Text(
          'Все данные группы «${group.title}» будут удалены безвозвратно.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.negative),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(groupsProvider.notifier).deleteGroup(group.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Группа «${group.title}» удалена')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось удалить группу: $e')),
      );
    }
  }

  Future<void> _leaveGroup(BuildContext context, GroupModel group) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Покинуть группу?'),
        content: Text(
          'Вы перестанете видеть группу «${group.title}», пока вас не пригласят снова.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.negative),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Покинуть'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(groupsProvider.notifier).leaveGroup(group.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Вы покинули «${group.title}»')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось выйти из группы: $e')),
      );
    }
  }
}

class _GroupTile extends StatelessWidget {
  final GroupModel group;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _GroupTile({
    required this.group,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = group.lastMessage;
    final previewAvatarUrl = _resolveAvatar(preview?.sender.avatarUrl);
    final previewTime = preview?.createdAt;
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              GroupAvatar(title: group.title),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.title,
                            style: theme.textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (previewTime != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            DateFormat('HH:mm').format(previewTime.toLocal()),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (preview != null)
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundImage: previewAvatarUrl != null
                                ? NetworkImage(previewAvatarUrl)
                                : null,
                            child: previewAvatarUrl == null
                                ? Text(
                                    preview.sender.displayLabel.isNotEmpty
                                        ? preview.sender.displayLabel[0].toUpperCase()
                                        : '?',
                                    style: theme.textTheme.labelSmall,
                                  )
                                : null,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              '${preview.sender.displayLabel}: ${preview.previewText}',
                              style: theme.textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        'Пока нет сообщений',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
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

  String? _resolveAvatar(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return '${AppConfig.apiOrigin}$trimmed';
  }
}
