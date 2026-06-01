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
import '../../groups/models/group_model.dart';
import '../../groups/widgets/create_group_sheet.dart';
import '../../groups/widgets/invite_member_sheet.dart';
import '../providers/chats_provider.dart';
import '../services/chats_service.dart';
import '../models/chat_message.dart';
import '../../../core/config/app_config.dart';

/// Unified list of all conversations — personal + group, sorted by last message time.
class ChatsListScreen extends ConsumerWidget {
  const ChatsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
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
      ),
      body: const _UnifiedChatList(),
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

// ─── Chat item union type ───────────────────────────────────────────────────

/// Wraps either a personal conversation or a group for unified sorting.
class _ChatItem {
  final PersonalChatPreview? personal;
  final GroupModel? group;

  const _ChatItem.personal(PersonalChatPreview this.personal) : group = null;
  const _ChatItem.group(GroupModel this.group) : personal = null;

  bool get isPersonal => personal != null;
  bool get isGroup => group != null;

  /// Returns the timestamp of the last message, used for sorting.
  DateTime get lastMessageAt {
    if (personal != null) {
      return personal!.lastMessage.createdAt;
    }
    return group!.lastMessage?.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
}

// ─── Unified chat list ──────────────────────────────────────────────────────

class _UnifiedChatList extends ConsumerWidget {
  const _UnifiedChatList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personalAsync = ref.watch(personalConversationsProvider);
    final groupsAsync = ref.watch(groupsProvider);
    final myUserId = ref.watch(authStateProvider).valueOrNull?.user?.id;

    // Show skeleton while either is loading
    if (personalAsync.isLoading || groupsAsync.isLoading) {
      return const _ChatsListSkeleton();
    }

    // Show error if both failed
    if (personalAsync.hasError && groupsAsync.hasError) {
      return AppErrorState(
        message: 'Не удалось загрузить чаты',
        onRetry: () {
          ref.read(personalConversationsProvider.notifier).refresh();
          ref.read(groupsProvider.notifier).refresh();
        },
      );
    }

    final personalList = personalAsync.valueOrNull ?? [];
    final groupsList = groupsAsync.valueOrNull ?? [];
    final personalFailed = personalAsync.hasError && personalList.isEmpty;

    if (personalList.isEmpty && groupsList.isEmpty) {
      return const AppEmptyState(
        icon: SolarIconsOutline.chatRound,
        message: 'Пока нет чатов',
        hint: 'Начните переписку или создайте группу',
      );
    }

    // Build unified list
    final items = <_ChatItem>[
      ...personalList.map((c) => _ChatItem.personal(c)),
      ...groupsList.map((g) => _ChatItem.group(g)),
    ];

    // Sort by last message time, descending (newest first)
    items.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

    return Column(
      children: [
        if (personalFailed)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => ref.read(personalConversationsProvider.notifier).refresh(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: AppColors.surfaceGlassStrong,
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.fgSoft),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Личные чаты не загрузились. Нажмите, чтобы повторить.',
                        style: TextStyle(fontSize: 13, color: AppColors.fgSoft),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                ref.read(personalConversationsProvider.notifier).refresh(),
                ref.read(groupsProvider.notifier).refresh(),
              ]);
            },
            child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (context, i) {
          final item = items[i];
          if (item.isPersonal) {
            final c = item.personal!;
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
          } else {
            final g = item.group!;
            final message = g.lastMessage;
            return _GroupConversationCard(
              avatarUrl: _groupAvatarUrl(g.avatarUrl),
              title: g.title,
              senderName: message?.sender.displayLabel,
              previewText: message == null
                  ? 'Создать первое сообщение'
                  : message.previewText,
              timeLabel: message?.createdAt == null
                  ? null
                  : DateFormat('HH:mm').format(message!.createdAt!.toLocal()),
              unreadCount: g.unreadCount,
              onTap: () => context.push(
                '/chats/group/${g.id}?title=${Uri.encodeComponent(g.title)}',
              ),
            );
          }
        },
      ),
    ),
        ),
      ],
    );
  }
}

// ─── Personal conversation card ─────────────────────────────────────────────

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
    final previewText = lastMessage.body.trim().isNotEmpty
        ? lastMessage.body
        : lastMessage.imageUrl != null
            ? 'Фото'
            : 'Сообщение';
    final timeLabel = DateFormat('HH:mm').format(lastMessage.createdAt.toLocal());
    final isRead = lastMessage.readAt != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Avatar with online dot
              _AvatarWithDot(
                avatarUrl: avatarUrl,
                initials: displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                isOnline: isOnline,
                icon: null,
              ),
              const SizedBox(width: 12),
              // Name + preview
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            previewText,
                            style: TextStyle(
                              fontSize: 13,
                              color: unreadCount > 0
                                  ? AppColors.white
                                  : AppColors.fgSoft,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (showStatus) ...[
                              Icon(
                                isRead ? Icons.done_all_rounded : Icons.done_rounded,
                                size: 14,
                                color: isRead ? AppColors.success : AppColors.fgSoft,
                              ),
                              const SizedBox(width: 3),
                            ],
                            Text(
                              timeLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.fgSoft,
                              ),
                            ),
                          ],
                        ),
                        if (unreadCount > 0) ...[
                          const SizedBox(height: 4),
                          _UnreadBadge(count: unreadCount),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Group conversation card ────────────────────────────────────────────────

class _GroupConversationCard extends StatelessWidget {
  final String? avatarUrl;
  final String title;
  final String? senderName;
  final String previewText;
  final String? timeLabel;
  final int unreadCount;
  final VoidCallback onTap;

  const _GroupConversationCard({
    required this.avatarUrl,
    required this.title,
    required this.senderName,
    required this.previewText,
    required this.timeLabel,
    this.unreadCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasMetaRight = timeLabel != null || unreadCount > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Avatar with group icon
              _AvatarWithDot(
                avatarUrl: avatarUrl,
                initials: title.isNotEmpty ? title[0].toUpperCase() : '?',
                isOnline: false,
                icon: SolarIconsOutline.usersGroupRounded,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            senderName != null ? '$senderName: $previewText' : previewText,
                            style: TextStyle(
                              fontSize: 13,
                              color: unreadCount > 0
                                  ? AppColors.white
                                  : AppColors.fgSoft,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (hasMetaRight) ...[
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (timeLabel != null)
                            Text(
                              timeLabel!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.fgSoft,
                              ),
                            ),
                          if (unreadCount > 0) ...[
                            const SizedBox(height: 4),
                            _UnreadBadge(count: unreadCount),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shared avatar widget ───────────────────────────────────────────────────

class _AvatarWithDot extends StatelessWidget {
  final String? avatarUrl;
  final String initials;
  final bool isOnline;
  final IconData? icon;

  const _AvatarWithDot({
    required this.avatarUrl,
    required this.initials,
    required this.isOnline,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            backgroundColor: const Color(0xFF2A2A2A),
            child: avatarUrl == null
                ? (icon != null
                    ? Icon(icon, size: 20, color: AppColors.fgSoft)
                    : Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white,
                        ),
                      ))
                : null,
          ),
          if (isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.bg1,
                    width: 2.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Unread badge ───────────────────────────────────────────────────────────

class _UnreadBadge extends StatelessWidget {
  final int count;

  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.fgContainer,
        ),
      ),
    );
  }
}

// ─── Groups manager sheet ───────────────────────────────────────────────────

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

/// Skeleton placeholder for the chats list while data is loading.
class _ChatsListSkeleton extends StatefulWidget {
  const _ChatsListSkeleton();

  @override
  State<_ChatsListSkeleton> createState() => _ChatsListSkeletonState();
}

class _ChatsListSkeletonState extends State<_ChatsListSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.3, end: 0.7).animate(_anim);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Widget _skeletonBox(double width, double height) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, __) => Opacity(
        opacity: _opacity.value,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
      ),
    );
  }

  Widget _skeletonItem() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _opacity,
            builder: (_, __) => Opacity(
              opacity: _opacity.value,
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFF2A2A2A),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _skeletonBox(120, 14),
                    const Spacer(),
                    _skeletonBox(36, 10),
                  ],
                ),
                const SizedBox(height: 6),
                _skeletonBox(200, 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
      itemCount: 6,
      itemBuilder: (_, __) => _skeletonItem(),
    );
  }
}
