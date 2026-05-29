import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:url_launcher/url_launcher.dart';

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

    return Scaffold(
      body: child,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: AppColors.bg2.withValues(alpha: 0.8),
              child: BottomNavigationBar(
                currentIndex: currentIndex < 0 ? 0 : currentIndex,
                onTap: (index) {
                  if (index != currentIndex) {
                    context.go(_tabs[index].path);
                  }
                },
                backgroundColor: Colors.transparent,
                elevation: 0,
                items: _tabs
                    .map((t) => BottomNavigationBarItem(
                          icon: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Icon(t.icon),
                          ),
                          activeIcon: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Icon(t.activeIcon),
                          ),
                          label: t.label,
                        ))
                    .toList(),
              ),
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
