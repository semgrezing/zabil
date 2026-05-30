import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_dimensions.dart';
import '../../../shared/widgets/app_loader.dart';
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
            itemCount: list.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 72),
            itemBuilder: (context, i) {
              final c = list[i];
              final displayName = _displayName(c.user);
              final avatarUrl = _avatarUrl(c.user);
              final preview = c.lastMessage.body.trim().isNotEmpty
                  ? c.lastMessage.body
                  : c.lastMessage.imageUrl != null
                      ? 'Фото'
                      : '';
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
                subtitle: Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: c.unreadCount > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.negative,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${c.unreadCount}',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : null,
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
      if (event is GroupMessageEvent) {
        final groupId = event.data['groupId']?.toString();
        if (groupId == null) return;
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
          itemCount: groups.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
          itemBuilder: (context, i) {
            final g = groups[i];
            return FutureBuilder<List<GroupChatMessage>>(
              future: _previewFuture(g.id),
              builder: (context, snapshot) {
                final message = snapshot.data?.isNotEmpty == true
                    ? snapshot.data!.first
                    : null;
                final subtitle = message == null
                    ? 'Создать первое сообщение'
                    : '${_displayName(message.sender)}: ${_previewText(message)}';
                final trailing = message == null
                    ? null
                    : Text(
                        DateFormat('HH:mm').format(message.createdAt.toLocal()),
                        style: Theme.of(context).textTheme.bodySmall,
                      );

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
                  subtitle: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: trailing,
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
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
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
