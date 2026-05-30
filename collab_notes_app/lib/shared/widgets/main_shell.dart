import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/groups/providers/groups_provider.dart';
import '../../features/notes/providers/notes_provider.dart';
import '../../features/updates/providers/update_provider.dart';
import '../theme/app_colors.dart';

final _updateBannerShownProvider = StateProvider<bool>((ref) => false);

class MainShell extends ConsumerWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  static const _tabs = [
    _TabItem(icon: SolarIconsOutline.notes, activeIcon: SolarIconsBold.notes, label: 'Заметки', path: '/notes'),
    _TabItem(icon: SolarIconsOutline.chatRound, activeIcon: SolarIconsBold.chatRound, label: 'Чаты', path: '/chats'),
    _TabItem(icon: SolarIconsOutline.settings, activeIcon: SolarIconsBold.settings, label: 'Настройки', path: '/settings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _tabs.indexWhere((t) => location.startsWith(t.path));
    final isNotesRoot = location == '/notes';
    final notesFilter = isNotesRoot ? ref.watch(notesFilterProvider) : null;
    final showFab = isNotesRoot && !(notesFilter?.showArchived ?? false);

    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: Padding(
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
                      return SizedBox(
                        width: 56,
                        height: 48,
                        child: IconButton(
                          icon: Icon(
                            isActive ? tab.activeIcon : tab.icon,
                            size: 22,
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
          content: Text('Загрузка контекстов...'),
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
        const SnackBar(content: Text('Контексты недоступны. Обновляю...')),
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
        showDragHandle: true,
        useRootNavigator: true,
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Выберите группу',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            ...contexts.map(
              (c) => ListTile(
                leading: Icon(
                  c.personal
                      ? SolarIconsOutline.user
                      : SolarIconsOutline.usersGroupRounded,
                ),
                title: Text(c.title),
                onTap: () => Navigator.of(ctx).pop(c),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
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
