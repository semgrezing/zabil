import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_dimensions.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../auth/providers/auth_provider.dart';
import '../../groups/providers/groups_provider.dart';
import '../../groups/widgets/create_group_sheet.dart';
import '../../groups/widgets/invite_member_sheet.dart';
import '../../../core/realtime/ws_client.dart';
import '../providers/chats_provider.dart';
import '../services/chats_service.dart';
import '../models/chat_message.dart';
import '../../../core/config/app_config.dart';

/// Список всех чатов — личные + групповые.
class ChatsListScreen extends ConsumerWidget {
  const ChatsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Чаты'),
          actions: [
            IconButton(
              icon: const Icon(SolarIconsOutline.usersGroupRounded),
              tooltip: 'Группы',
              onPressed: () => _openGroupsManager(context, ref),
            ),
            IconButton(
              icon: const Icon(SolarIconsOutline.userPlus),
              tooltip: 'Новый личный чат',
              onPressed: () => _startPersonalChat(context, ref),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Личные'),
              Tab(text: 'Группы'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PersonalTab(),
            _GroupsTab(),
          ],
        ),
      ),
    );
  }

  Future<void> _startPersonalChat(BuildContext context, WidgetRef ref) async {
    final picked = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useRootNavigator: true,
      builder: (_) => const _UserSearchSheet(),
    );
    if (picked != null && context.mounted) {
      final title = _displayName(picked);
      context.push('/chats/personal/${picked['id']}?username=$title');
    }
  }

  Future<void> _openGroupsManager(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useRootNavigator: true,
      builder: (_) => const _GroupsManagerSheet(),
    );
  }
}

class _PersonalTab extends ConsumerWidget {
  const _PersonalTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(personalConversationsProvider);
    final myUserId = ref.watch(authStateProvider).valueOrNull?.user?.id;
    return async.when(
      loading: () => const AppLoader(),
      error: (e, _) => AppErrorState(
        message: 'Не удалось загрузить личные чаты',
        onRetry: () =>
            ref.read(personalConversationsProvider.notifier).refresh(),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const AppEmptyState(
            icon: SolarIconsOutline.userPlus,
            message: 'Пока нет личных чатов',
            hint: 'Нажмите ＋ сверху, чтобы начать переписку',
          );
        }
        return RefreshIndicator(
          onRefresh: () =>
              ref.read(personalConversationsProvider.notifier).refresh(),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, i) {
              final c = list[i];
              final displayName = _displayName(c.user);
              final avatarUrl = _avatarUrl(c.user);
              return _PersonalConversationCard(
                avatarUrl: avatarUrl,
                displayName: displayName,
                isOnline: c.isOnline,
                unreadCount: c.unreadCount,
                lastMessage: c.lastMessage,
                showStatus: c.lastMessage.senderId == myUserId,
                onTap: () => context.push(
                  '/chats/personal/${c.user['id']}?username=$displayName',
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _GroupsTab extends ConsumerStatefulWidget {
  const _GroupsTab();

  @override
  ConsumerState<_GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends ConsumerState<_GroupsTab> {
  final _service = ChatsService();
  final Map<String, Future<List<GroupChatMessage>>> _previewFutures = {};
  StreamSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
    final ws = ref.read(wsClientProvider);
    _wsSub = ws.events.listen((event) {
      if (event is WsReconnectedEvent) {
        // Clear all cached previews so they refetch with fresh data
        setState(() {
          _previewFutures.clear();
        });
        return;
      }
      if (event is GroupMessageEvent) {
        final groupId = event.data['groupId']?.toString();
        if (groupId == null) return;
        setState(() {
          _previewFutures.remove(groupId);
        });
        return;
      }
      if (event is GroupReadReceiptEvent) {
        final groupId = event.groupId;
        if (groupId.isEmpty) return;
        setState(() {
          _previewFutures.remove(groupId);
        });
      }
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  Future<List<GroupChatMessage>> _previewFuture(String groupId) {
    return _previewFutures[groupId] ??=
        _service.getGroupMessages(groupId, limit: 1);
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsProvider);
    final myUserId = ref.watch(authStateProvider).valueOrNull?.user?.id;
    return groupsAsync.when(
      loading: () => const AppLoader(),
      error: (e, _) => AppErrorState(
        message: 'Не удалось загрузить группы',
        onRetry: () => ref.read(groupsProvider.notifier).refresh(),
      ),
      data: (groups) {
        if (groups.isEmpty) {
          return const AppEmptyState(
            icon: SolarIconsOutline.usersGroupRounded,
            message: 'Вы пока не в группе',
            hint: 'Создайте группу или примите приглашение',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
          itemCount: groups.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (context, i) {
            final g = groups[i];
            return FutureBuilder<List<GroupChatMessage>>(
              future: _previewFuture(g.id),
              builder: (context, snapshot) {
                final message = snapshot.data?.isNotEmpty == true
                    ? snapshot.data!.first
                    : null;
                return _GroupConversationCard(
                  avatarUrl: _groupAvatarUrl(g.avatarUrl),
                  title: g.title,
                  senderName: message == null ? null : _displayName(message.sender),
                  previewText: message == null
                      ? 'Создать первое сообщение'
                      : _previewText(message),
                  timeLabel: message == null
                      ? null
                      : DateFormat('HH:mm').format(message.createdAt.toLocal()),
                  showStatus: message != null && message.senderId == myUserId,
                  isRead: message?.isReadByMe ?? false,
                  readCount: message?.readCount ?? 0,
                  onTap: () => context.push(
                    '/chats/group/${g.id}?title=${Uri.encodeComponent(g.title)}',
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _previewText(GroupChatMessage message) {
    if (message.body.trim().isNotEmpty) return message.body;
    if (message.imageUrl != null) return 'Фото';
    return 'Сообщение';
  }
}

class _GroupsManagerSheet extends ConsumerWidget {
  const _GroupsManagerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Группы',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(SolarIconsOutline.refresh),
                    onPressed: () => ref.read(groupsProvider.notifier).refresh(),
                  ),
                  IconButton(
                    icon: const Icon(SolarIconsOutline.addCircle),
                    tooltip: 'Создать группу',
                    onPressed: () => _openCreateGroup(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: groupsAsync.when(
                loading: () => const AppLoader(),
                error: (e, _) => AppErrorState(
                  message: 'Не удалось загрузить группы',
                  onRetry: () => ref.read(groupsProvider.notifier).refresh(),
                ),
                data: (groups) {
                  if (groups.isEmpty) {
                    return const AppEmptyState(
                      icon: SolarIconsOutline.usersGroupRounded,
                      message: 'Нет групп',
                      hint: 'Создайте первую группу',
                    );
                  }
                  return ListView.separated(
                    itemCount: groups.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final g = groups[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: _groupAvatarUrl(g.avatarUrl) != null
                              ? NetworkImage(_groupAvatarUrl(g.avatarUrl)!)
                              : null,
                          child: _groupAvatarUrl(g.avatarUrl) == null
                              ? Text(g.title.isNotEmpty ? g.title[0].toUpperCase() : '?')
                              : null,
                        ),
                        title: Text(g.title),
                        subtitle: Text('${g.members.length} участников'),
                        trailing: IconButton(
                          icon: const Icon(SolarIconsOutline.userPlus),
                          tooltip: 'Пригласить в группу',
                          onPressed: () => _openInvite(context, g.id, g.title),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          context.push('/groups/${g.id}');
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCreateGroup(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useRootNavigator: true,
      builder: (_) => const CreateGroupSheet(),
    );
  }

  Future<void> _openInvite(BuildContext context, String id, String title) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useRootNavigator: true,
      builder: (_) => InviteMemberSheet(groupId: id, groupTitle: title),
    );
  }
}

/// Bottom sheet поиска пользователя для нового личного чата.
class _UserSearchSheet extends ConsumerStatefulWidget {
  const _UserSearchSheet();

  @override
  ConsumerState<_UserSearchSheet> createState() => _UserSearchSheetState();
}

class _UserSearchSheetState extends ConsumerState<_UserSearchSheet> {
  final _ctrl = TextEditingController();
  List<Map<String, String>> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final results = await ChatsService().searchUsers(query.trim());
      if (mounted) {
        setState(() {
          _results = results;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final topPadding = MediaQuery.of(context).viewPadding.top;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85 - topPadding,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  onChanged: _search,
                  decoration: const InputDecoration(
                    hintText: 'Поиск по никнейму среди пользователей ваших групп',
                    prefixIcon: Icon(SolarIconsOutline.magnifier),
                    filled: true,
                  ),
                ),
              ),
              if (_loading) const LinearProgressIndicator(minHeight: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, i) {
                    final user = _results[i];
                    final username = user['username'] ?? '?';
                    final displayName = _displayName(user);
                    final avatarUrl = _avatarUrl(user);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null
                            ? Text(displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : '?')
                            : null,
                      ),
                      title: Text(displayName),
                      subtitle:
                          displayName != username ? Text('@$username') : null,
                      onTap: () => Navigator.of(context).pop(user),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _displayName(Map<String, String> user) {
  final name = user['displayName']?.trim();
  if (name != null && name.isNotEmpty) return name;
  return user['username'] ?? '?';
}

String? _avatarUrl(Map<String, String> user) {
  final raw = user['avatarUrl']?.trim();
  if (raw == null || raw.isEmpty) return null;
  if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
  return '${AppConfig.apiOrigin}$raw';
}

String? _groupAvatarUrl(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  return '${AppConfig.apiOrigin}$value';
}

class _OnlineDot extends StatelessWidget {
  final bool isOnline;

  const _OnlineDot({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    if (!isOnline) return const SizedBox.shrink();
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: Colors.green.shade600,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.surface,
          width: 1.5,
        ),
      ),
    );
  }
}

class _PersonalConversationCard extends StatelessWidget {
  final String? avatarUrl;
  final String displayName;
  final bool isOnline;
  final int unreadCount;
  final PersonalChatMessage lastMessage;
  final bool showStatus;
  final VoidCallback onTap;

  const _PersonalConversationCard({
    required this.avatarUrl,
    required this.displayName,
    required this.isOnline,
    required this.unreadCount,
    required this.lastMessage,
    required this.showStatus,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _ConversationCardShell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF2A2A2A),
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                child: avatarUrl == null
                    ? Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                        style: const TextStyle(color: AppColors.white),
                      )
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: _OnlineDot(isOnline: isOnline),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _MessageMeta(
                      timeLabel: DateFormat('HH:mm').format(lastMessage.createdAt.toLocal()),
                      showStatus: showStatus,
                      isRead: lastMessage.readAt != null,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _previewTextPersonal(lastMessage),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.fgSoft,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (unreadCount > 0) ...[
            const SizedBox(width: 12),
            _ConversationCounter(count: unreadCount),
          ],
        ],
      ),
    );
  }
}

class _GroupConversationCard extends StatelessWidget {
  final String? avatarUrl;
  final String title;
  final String? senderName;
  final String previewText;
  final String? timeLabel;
  final bool showStatus;
  final bool isRead;
  final int readCount;
  final VoidCallback onTap;

  const _GroupConversationCard({
    required this.avatarUrl,
    required this.title,
    required this.senderName,
    required this.previewText,
    required this.timeLabel,
    required this.showStatus,
    required this.isRead,
    required this.readCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _ConversationCardShell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF2A2A2A),
            backgroundImage:
                avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null
                ? Text(
                    title.isNotEmpty ? title[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppColors.white),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ),
                    if (timeLabel != null) ...[
                      const SizedBox(width: 12),
                      _MessageMeta(
                        timeLabel: timeLabel!,
                        showStatus: showStatus,
                        isRead: isRead || readCount > 0,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                if (senderName != null) ...[
                  Text(
                    senderName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.fgSoft,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  previewText,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.fgSoft,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationCardShell extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _ConversationCardShell({required this.child, required this.onTap});

  @override
  State<_ConversationCardShell> createState() => _ConversationCardShellState();
}

class _ConversationCardShellState extends State<_ConversationCardShell> {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(24),
        hoverColor: Colors.white.withValues(alpha: 0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: widget.child,
        ),
      ),
    );
  }
}

class _MessageMeta extends StatelessWidget {
  final String timeLabel;
  final bool showStatus;
  final bool isRead;

  const _MessageMeta({
    required this.timeLabel,
    required this.showStatus,
    required this.isRead,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showStatus) ...[
          Icon(
            isRead ? Icons.done_all : Icons.done,
            size: 14,
            color: isRead ? const Color(0xFFB6FF35) : AppColors.fgSoft,
          ),
          const SizedBox(width: 6),
        ],
        Text(
          timeLabel,
          style: const TextStyle(
            color: AppColors.fgSoft,
            fontSize: 12,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _ConversationCounter extends StatelessWidget {
  final int count;

  const _ConversationCounter({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0059FF),
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 13,
          height: 1.1,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _previewTextPersonal(PersonalChatMessage message) {
  final body = message.body.trim();
  if (body.isNotEmpty) return body;
  if (message.imageUrl != null) return 'Фото';
  return 'Сообщение';
}
