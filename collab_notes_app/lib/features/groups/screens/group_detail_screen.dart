import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:solar_icons/solar_icons.dart';
import '../models/group_model.dart';
import '../providers/groups_provider.dart';
import '../widgets/invite_member_sheet.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/widgets/avatar_history_viewer.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  bool _updatingAvatar = false;

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsProvider);
    final currentUserId = ref.watch(authStateProvider).valueOrNull?.user?.id;

    return groupsAsync.when(
      loading: () => const Scaffold(body: AppLoader()),
      error: (err, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Ошибка: $err')),
      ),
      data: (groups) {
        final group = groups.where((g) => g.id == widget.groupId).firstOrNull;
        if (group == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Группа не найдена')),
          );
        }

        // Роль текущего пользователя в группе
        final me = currentUserId == null
            ? null
            : group.members
                .where((m) => m.userId == currentUserId)
                .firstOrNull;
        final isOwner = me?.role == 'owner';
        final isAdmin = me?.role == 'admin';
        final canManage = isOwner || isAdmin;
        final avatarUrl = _resolveAvatar(group.avatarUrl);

        return Scaffold(
          appBar: AppBar(
            title: Text(group.title),
            actions: [
              IconButton(
                icon: const Icon(SolarIconsOutline.chatRound),
                tooltip: 'Чат группы',
                onPressed: () => context.push(
                  '/chats/group/${group.id}?title=${Uri.encodeComponent(group.title)}',
                ),
              ),
              IconButton(
                icon: const Icon(SolarIconsOutline.userPlus),
                tooltip: 'Пригласить участника',
                onPressed: () =>
                    _openInviteSheet(context, group.id, group.title),
              ),
              if (canManage)
                IconButton(
                  icon: _updatingAvatar
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(SolarIconsOutline.settings),
                  tooltip: 'Настройки группы',
                  onPressed: _updatingAvatar
                      ? null
                      : () => _openManageSheet(context, group, canManage),
                ),
              _GroupOverflowMenu(
                group: group,
                isOwner: isOwner,
                canLeave: me != null && !isOwner,
                ref: ref,
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => _openAvatarViewer(context, group, canManage),
                      child: CircleAvatar(
                        radius: 38,
                        backgroundImage:
                            avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null
                            ? Text(
                                group.title.isNotEmpty
                                    ? group.title[0].toUpperCase()
                                    : '?',
                                style: Theme.of(context).textTheme.titleLarge,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      group.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              const Divider(),
              ...group.members.map((member) {
                final memberAvatarUrl = _resolveAvatar(member.avatarUrl);
                final canKick = canManage && member.role == 'member';
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage:
                        memberAvatarUrl != null ? NetworkImage(memberAvatarUrl) : null,
                    child: memberAvatarUrl == null
                        ? Text(member.displayLabel[0].toUpperCase())
                        : null,
                  ),
                  title: Text(member.displayLabel),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _roleChip(context, member.role),
                      if (canKick)
                        IconButton(
                          icon: const Icon(Icons.person_remove_alt_1),
                          tooltip: 'Исключить',
                          onPressed: () => _kickMember(context, group, member),
                        ),
                    ],
                  ),
                );
              }),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(SolarIconsOutline.notes),
            label: const Text('Заметки группы'),
            onPressed: () => context.go('/notes?groupId=${widget.groupId}'),
          ),
        );
      },
    );
  }

  Future<void> _openInviteSheet(
      BuildContext context, String id, String title) async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => InviteMemberSheet(groupId: id, groupTitle: title),
    );
    if (sent == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Приглашение отправлено')),
      );
    }
  }

  Widget _roleChip(BuildContext context, String role) {
    const labels = {'owner': 'Создатель', 'admin': 'Админ', 'member': 'Участник'};
    return Chip(
      label: Text(labels[role] ?? role),
      visualDensity: VisualDensity.compact,
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

  Future<void> _kickMember(
    BuildContext context,
    GroupModel group,
    GroupMemberModel member,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Исключить участника?'),
        content: Text('Пользователь ${member.displayLabel} будет исключен из группы.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.negative),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Исключить'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await ref.read(groupsProvider.notifier).removeMember(group.id, member.userId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.displayLabel} исключен из группы')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось исключить участника: $e')),
      );
    }
  }

  Future<void> _openManageSheet(
    BuildContext context,
    GroupModel group,
    bool canManage,
  ) async {
    final titleCtrl = TextEditingController(text: group.title);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Настройки группы', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Название группы'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => _changeAvatar(group),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Аватарка'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openAvatarViewer(context, group, canManage),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('История аватарок'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(groupsProvider.notifier).deleteAvatar(group.id);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Текущая аватарка удалена')),
                    );
                  },
                  icon: const Icon(SolarIconsOutline.trashBinTrash),
                  label: const Text('Удалить текущую'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Закрыть'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final nextTitle = titleCtrl.text.trim();
                      if (nextTitle.isEmpty || nextTitle == group.title) {
                        Navigator.of(ctx).pop();
                        return;
                      }
                      await ref.read(groupsProvider.notifier).updateGroupTitle(
                            group.id,
                            nextTitle,
                          );
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                    child: const Text('Сохранить'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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

    setState(() => _updatingAvatar = true);
    try {
      await ref.read(groupsProvider.notifier).uploadAvatar(group.id, cropped.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось обновить аватарку: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingAvatar = false);
    }
  }

  Future<void> _openAvatarViewer(
    BuildContext context,
    GroupModel group,
    bool canDelete,
  ) async {
    final service = ref.read(groupsServiceProvider);
    final historyRaw = await service.getGroupAvatarHistory(group.id);

    final entries = historyRaw
        .map(
          (e) => AvatarHistoryEntry(
            id: e['id'] as String,
            imageUrl: _resolveAvatar(e['avatarUrl'] as String?) ?? '',
            createdAt: DateTime.tryParse((e['createdAt'] ?? '').toString()),
          ),
        )
        .where((e) => e.imageUrl.isNotEmpty)
        .toList();

    if (entries.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('История аватарок пока пуста')),
      );
      return;
    }

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AvatarHistoryViewer(
          title: group.title,
          entries: entries,
          canDelete: canDelete,
          onDelete: (entry) async {
            await service.deleteGroupAvatarHistoryItem(group.id, entry.id);
            await ref.read(groupsProvider.notifier).refresh();
          },
        ),
      ),
    );
  }
}

/// Меню в AppBar: «Удалить» для владельца, «Выйти» для остальных.
class _GroupOverflowMenu extends StatelessWidget {
  final GroupModel group;
  final bool isOwner;
  final bool canLeave;
  final WidgetRef ref;

  const _GroupOverflowMenu({
    required this.group,
    required this.isOwner,
    required this.canLeave,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOwner && !canLeave) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      icon: const Icon(SolarIconsOutline.menuDots),
      tooltip: 'Меню',
      onSelected: (action) async {
        switch (action) {
          case 'delete':
            await _confirmDelete(context);
            break;
          case 'leave':
            await _confirmLeave(context);
            break;
        }
      },
      itemBuilder: (_) => [
        if (isOwner)
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              dense: true,
              leading: Icon(SolarIconsBold.trashBinTrash,
                  color: AppColors.negative, size: 20),
              title: Text('Удалить группу',
                  style: TextStyle(color: AppColors.negative)),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (canLeave)
          const PopupMenuItem(
            value: 'leave',
            child: ListTile(
              dense: true,
              leading: Icon(SolarIconsBold.logout,
                  color: AppColors.negative, size: 20),
              title: Text('Выйти из группы',
                  style: TextStyle(color: AppColors.negative)),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить группу?'),
        content: Text(
          'Все заметки и участники группы «${group.title}» будут удалены безвозвратно.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.negative),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(groupsProvider.notifier).deleteGroup(group.id);
      if (!context.mounted) return;
      context.go('/groups');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Группа «${group.title}» удалена')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e, 'удалить'))),
      );
    }
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выйти из группы?'),
        content: Text(
          'Вы перестанете видеть заметки группы «${group.title}». Чтобы вернуться — попросите участников пригласить вас снова.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.negative),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(groupsProvider.notifier).leaveGroup(group.id);
      if (!context.mounted) return;
      context.go('/groups');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Вы вышли из «${group.title}»')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e, 'выйти'))),
      );
    }
  }

  String _friendlyError(Object e, String action) {
    final s = e.toString().toLowerCase();
    if (s.contains('connection') ||
        s.contains('socketexception') ||
        s.contains('network')) {
      return 'Нет соединения с сервером';
    }
    if (s.contains('403') || s.contains('forbidden')) {
      return 'Недостаточно прав';
    }
    if (s.contains('400')) {
      return 'Создатель не может покинуть группу — удалите её';
    }
    return 'Не удалось $action группу';
  }
}
