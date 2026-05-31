import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../auth/providers/auth_provider.dart';
import '../../groups/providers/groups_provider.dart';
import '../../invitations/services/invitations_service.dart';
import '../models/chat_user_profile.dart';
import '../services/chats_service.dart';

class ChatUserProfileScreen extends ConsumerWidget {
  final String userId;

  const ChatUserProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ChatsService();
    final currentUserId = ref.watch(authStateProvider).valueOrNull?.user?.id;
    final isSelf = currentUserId == userId;
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль пользователя')),
      body: FutureBuilder<ChatUserProfile>(
        future: service.getUserProfile(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoader();
          }
          if (snapshot.hasError) {
            return Center(child: Text('Не удалось загрузить профиль: ${snapshot.error}'));
          }
          final profile = snapshot.data;
          if (profile == null) {
            return const Center(child: Text('Профиль не найден'));
          }

          final avatar = _resolveUrl(profile.avatarUrl);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                    child: avatar == null
                        ? Text(
                            profile.displayLabel.isNotEmpty
                                ? profile.displayLabel[0].toUpperCase()
                                : '?',
                            style: const TextStyle(fontSize: 22),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.displayLabel,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${profile.username}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.fgSoft),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _presenceLabel(profile),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: profile.isOnline
                                    ? Colors.green.shade700
                                    : AppColors.fgSoft,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!isSelf) ...[
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => context.push(
                          '/chats/personal/${profile.id}?username=${Uri.encodeComponent(profile.displayLabel)}',
                        ),
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Написать сообщение'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _inviteToGroup(context, ref, profile),
                        icon: const Icon(Icons.group_add_outlined),
                        label: const Text('Пригласить в группу'),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              _Section(
                title: 'Общие группы',
                child: profile.commonGroups.isEmpty
                    ? const Text('Нет общих групп')
                    : Column(
                        children: profile.commonGroups
                            .map((g) => ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    radius: 14,
                                    backgroundImage: _resolveUrl(g.avatarUrl) != null
                                        ? NetworkImage(_resolveUrl(g.avatarUrl)!)
                                        : null,
                                    child: _resolveUrl(g.avatarUrl) == null
                                        ? Text(
                                            g.title.isNotEmpty
                                                ? g.title[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(fontSize: 10),
                                          )
                                        : null,
                                  ),
                                  title: Text(g.title),
                                  subtitle: Text('${g.membersCount} участников'),
                                  onTap: () => context.push('/groups/${g.id}'),
                                ))
                            .toList(),
                      ),
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'История аватарок',
                child: profile.avatarHistory.isEmpty
                    ? const Text('История аватарок пуста')
                    : Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: profile.avatarHistory.map((item) {
                          final url = _resolveUrl(item.avatarUrl);
                          return SizedBox(
                            width: 92,
                            child: Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    width: 72,
                                    height: 72,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    child: url == null
                                        ? const Icon(Icons.image_not_supported_outlined)
                                        : Image.network(
                                            url,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(Icons.broken_image_outlined),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('dd.MM.yyyy').format(item.createdAt.toLocal()),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppColors.fgSoft),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  String? _resolveUrl(String? raw) {
    final v = raw?.trim();
    if (v == null || v.isEmpty) return null;
    if (v.startsWith('http://') || v.startsWith('https://')) return v;
    return '${AppConfig.apiOrigin}$v';
  }

  String _presenceLabel(ChatUserProfile profile) {
    if (profile.isOnline) return 'В сети';
    final lastSeen = profile.lastSeenAt;
    if (lastSeen == null) return 'Не в сети';
    final now = DateTime.now();
    final diff = now.difference(lastSeen.toLocal());
    if (diff.inMinutes < 1) return 'Был(а) только что';
    if (diff.inMinutes < 60) return 'Был(а) ${diff.inMinutes} мин назад';
    if (diff.inHours < 24) return 'Был(а) ${diff.inHours} ч назад';
    return 'Был(а) ${DateFormat('dd.MM.yyyy HH:mm').format(lastSeen.toLocal())}';
  }

  Future<void> _inviteToGroup(
    BuildContext context,
    WidgetRef ref,
    ChatUserProfile profile,
  ) async {
    final groups = ref.read(groupsProvider).valueOrNull ?? const [];
    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала создайте группу для приглашения')),
      );
      return;
    }

    final groupId = groups.length == 1
        ? groups.first.id
        : await showModalBottomSheet<String>(
            context: context,
            showDragHandle: true,
            builder: (sheetContext) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: groups
                    .map(
                      (group) => ListTile(
                        leading: const Icon(Icons.group_outlined),
                        title: Text(group.title),
                        onTap: () => Navigator.of(sheetContext).pop(group.id),
                      ),
                    )
                    .toList(),
              ),
            ),
          );
    if (groupId == null || groupId.isEmpty) return;

    try {
      await InvitationsService().sendInvitation(groupId, profile.username);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Приглашение для @${profile.username} отправлено')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отправить приглашение: $e')),
      );
    }
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}