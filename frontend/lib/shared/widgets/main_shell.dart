import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';

class MainShell extends ConsumerWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  static const _tabs = [
    _TabItem(icon: Icons.notes_outlined, activeIcon: Icons.notes, label: 'Заметки', path: '/notes'),
    _TabItem(icon: Icons.search_outlined, activeIcon: Icons.search, label: 'Поиск', path: '/search'),
    _TabItem(icon: Icons.mail_outline, activeIcon: Icons.mail, label: 'Приглашения', path: '/invitations'),
    _TabItem(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: 'Настройки', path: '/settings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _tabs.indexWhere((t) => location.startsWith(t.path));

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex < 0 ? 0 : currentIndex,
        onTap: (index) {
          if (index != currentIndex) {
            context.go(_tabs[index].path);
          }
        },
        items: _tabs
            .map((t) => BottomNavigationBarItem(
                  icon: Icon(t.icon),
                  activeIcon: Icon(t.activeIcon),
                  label: t.label,
                ))
            .toList(),
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
