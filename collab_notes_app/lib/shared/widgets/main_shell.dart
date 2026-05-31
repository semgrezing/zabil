import 'dart:io';
import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/chats/providers/chats_provider.dart';
import '../../features/groups/providers/groups_provider.dart';
import '../../features/notes/providers/notes_provider.dart';
import '../../features/updates/providers/update_provider.dart';
import '../../features/invitations/providers/invitations_provider.dart';
import '../../core/realtime/ws_client.dart';
import '../theme/app_colors.dart';

final _updateBannerShownProvider = StateProvider<bool>((ref) => false);

class MainShell extends ConsumerStatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  StreamSubscription? _pushSub;

  static const _tabs = [
    _TabItem(icon: SolarIconsOutline.notes, activeIcon: SolarIconsBold.notes, label: 'Заметки', path: '/notes'),
    _TabItem(icon: SolarIconsOutline.chatRound, activeIcon: SolarIconsBold.chatRound, label: 'Чаты', path: '/chats'),
    _TabItem(icon: SolarIconsOutline.settings, activeIcon: SolarIconsBold.settings, label: 'Настройки', path: '/settings'),
  ];

  @override
  void initState() {
    super.initState();
    _pushSub = ref
        .read(wsClientProvider)
        .events
        .where((e) => e is PushNotificationEvent)
        .cast<PushNotificationEvent>()
        .listen(_handlePushToast);
  }

  @override
  void dispose() {
    _pushSub?.cancel();
    super.dispose();
  }

  void _handlePushToast(PushNotificationEvent event) {
    if (!mounted) return;
    final type = event.data['type']?.toString();
    final messenger = ScaffoldMessenger.of(context);

    switch (type) {
      case 'invitation':
        ref.invalidate(invitationsProvider);
        messenger.showSnackBar(
          const SnackBar(content: Text('Получено новое приглашение в группу')),
        );
        break;
      case 'invitation_accepted':
        messenger.showSnackBar(
          const SnackBar(content: Text('Ваше приглашение принято')),
        );
        break;
      case 'invitation_declined':
        messenger.showSnackBar(
          const SnackBar(content: Text('Ваше приглашение отклонено')),
        );
        break;
      case 'group_member_removed':
      case 'group_deleted':
        ref.invalidate(groupsProvider);
        ref.invalidate(notesProvider);
        messenger.showSnackBar(
          SnackBar(content: Text(event.body.isNotEmpty ? event.body : 'Обновлен доступ к группе')),
        );
        break;
      case 'app_release':
        final platform = event.data['platform']?.toString();
        final downloadUrl = event.data['downloadUrl']?.toString();
        final currentPlatform = Platform.isAndroid
            ? 'android'
            : Platform.isWindows
                ? 'windows'
                : Platform.operatingSystem;
        if (platform != null && platform != currentPlatform) break;
        ref.invalidate(updateCheckProvider);
        messenger.showSnackBar(
          SnackBar(
            content: Text(event.body.isNotEmpty
                ? event.body
                : 'Доступна версия ${event.data['version'] ?? ''}'),
            duration: const Duration(seconds: 15),
            action: downloadUrl == null || downloadUrl.isEmpty
                ? null
                : SnackBarAction(
                    label: 'Скачать',
                    onPressed: () => launchUrl(Uri.parse(downloadUrl)),
                  ),
          ),
        );
        break;
      default:
        break;
    }
  }

  /// Total unread count across personal + group conversations.
  int _totalUnread(WidgetRef ref) {
    final personalList = ref.watch(personalConversationsProvider).valueOrNull ?? [];
    final personalUnread = personalList.fold<int>(0, (sum, c) => sum + c.unreadCount);
    // TODO(B17): Add group unread counts once backend provides them
    final groupsList = ref.watch(groupsProvider).valueOrNull ?? [];
    final groupUnread = groupsList.fold<int>(0, (sum, g) => sum + g.unreadCount);
    return personalUnread + groupUnread;
  }

  @override
  Widget build(BuildContext context) {
    final updateInfo = ref.watch(updateCheckProvider).valueOrNull;
    final bannerShown = ref.watch(_updateBannerShownProvider);
    if (updateInfo != null &&
        updateInfo.hasUpdate &&
        !updateInfo.mandatory &&
        updateInfo.downloadUrl != null &&
        !bannerShown) {
      ref.read(_updateBannerShownProvider.notifier).state = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Доступна версия ${updateInfo.latestVersion}'),
            duration: const Duration(seconds: 15),
            action: SnackBarAction(
              label: 'Скачать',
              onPressed: () => launchUrl(Uri.parse(updateInfo.downloadUrl!)),
            ),
          ),
        );
      });
    }

    final state = GoRouterState.of(context);
    final location = state.uri.path;
    final currentIndex = _tabs.indexWhere((t) => location.startsWith(t.path));
    final isNotesRoot = location == '/notes';
    final isNoteEditorRoute = location == '/notes/new' ||
        (location.startsWith('/notes/') && location != '/notes');
    final hideBottomNavbar = isNoteEditorRoute;
    final notesFilter = isNotesRoot ? ref.watch(notesFilterProvider) : null;
    final showFab = isNotesRoot && !(notesFilter?.showArchived ?? false);

    return Scaffold(
      extendBody: true,
      body: widget.child,
      bottomNavigationBar: hideBottomNavbar
          ? null
          : Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 8,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.bg2.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _tabs.asMap().entries.map((entry) {
                      final index = entry.key;
                      final tab = entry.value;
                      final isActive = index == (currentIndex < 0 ? 0 : currentIndex);
                      // Compute unread badge for Chats tab (index 1)
                      final badgeCount = index == 1 ? _totalUnread(ref) : 0;
                      return SizedBox(
                        width: 56,
                        height: 48,
                        child: IconButton(
                          icon: Badge(
                            isLabelVisible: badgeCount > 0,
                            label: Text(
                              badgeCount > 99 ? '99+' : badgeCount.toString(),
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
                            ),
                            child: Icon(
                              isActive ? tab.activeIcon : tab.icon,
                              size: 22,
                            ),
                          ),
                          color: isActive ? AppColors.white : AppColors.fgSoft,
                          tooltip: tab.label,
                          onPressed: () {
                            if (index != currentIndex) {
                              context.go(tab.path);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            if (showFab) ...[
              const SizedBox(width: 12),
              _NoteFab(),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoteFab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _createNote(context, ref),
        child: const SizedBox(
          width: 56,
          height: 48,
          child: Icon(Icons.add_rounded, color: AppColors.fgContainer, size: 28),
        ),
      ),
    );
  }

  Future<void> _createNote(BuildContext context, WidgetRef ref) async {
    final filter = ref.read(notesFilterProvider);

    if (filter.personal) {
      context.go('/notes/new?personal=true');
      return;
    }

    if (filter.groupId != null && filter.groupId!.isNotEmpty) {
      context.go('/notes/new?groupId=${filter.groupId!}');
      return;
    }

    final groupsAsync = ref.read(groupsProvider);
    final personalAsync = ref.read(personalContextProvider);

    if (groupsAsync.isLoading || personalAsync.isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Загрузка групп...'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    final groups = groupsAsync.valueOrNull ?? [];
    final personal = personalAsync.valueOrNull;

    if (groups.isEmpty && personal == null) {
      ref.invalidate(groupsProvider);
      ref.invalidate(personalContextProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Группы недоступны. Обновляю...')),
      );
      return;
    }

    final contexts = <_NoteContext>[
      if (personal != null) _NoteContext(id: personal.id, title: 'Личное', personal: true),
      ...groups.map((g) => _NoteContext(id: g.id, title: g.title, personal: false)),
    ];

    if (contexts.length == 1) {
      final one = contexts.first;
      if (one.personal) {
        context.go('/notes/new?personal=true');
      } else {
        context.go('/notes/new?groupId=${one.id}');
      }
    } else {
      final selected = await showModalBottomSheet<_NoteContext>(
        context: context,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black54,
        clipBehavior: Clip.antiAlias,
        constraints: const BoxConstraints(maxWidth: 393),
        showDragHandle: false,
        useRootNavigator: true,
        builder: (ctx) => _NoteLocationSheet(contexts: contexts),
      );
      if (selected != null && context.mounted) {
        if (selected.personal) {
          context.go('/notes/new?personal=true');
        } else {
          context.go('/notes/new?groupId=${selected.id}');
        }
      }
    }
  }
}

class _NoteContext {
  final String id;
  final String title;
  final bool personal;
  const _NoteContext({required this.id, required this.title, required this.personal});
}

class _NoteLocationSheet extends StatelessWidget {
  final List<_NoteContext> contexts;

  const _NoteLocationSheet({required this.contexts});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFF1F1F1F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const _BottomSheetHandle(),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Выберите, где создать заметку',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final contextItem in contexts) ...[
                    _NoteLocationOption(
                      title: contextItem.title,
                      personal: contextItem.personal,
                      onTap: () => Navigator.of(context).pop(contextItem),
                    ),
                    if (contextItem != contexts.last) const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomSheetHandle extends StatelessWidget {
  const _BottomSheetHandle();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF9C9C9C),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _NoteLocationOption extends StatelessWidget {
  final String title;
  final bool personal;
  final VoidCallback onTap;

  const _NoteLocationOption({
    required this.title,
    required this.personal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        hoverColor: Colors.white.withValues(alpha: 0.05),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2A2A2A),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
                if (personal)
                  const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Icon(
                      SolarIconsOutline.user,
                      size: 18,
                      color: AppColors.fgSoft,
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Icon(
                      SolarIconsOutline.usersGroupRounded,
                      size: 18,
                      color: AppColors.fgSoft,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;

  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
  });
}
