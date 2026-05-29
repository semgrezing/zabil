import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/notifications/notification_service.dart';
import 'router.dart';
import 'shared/theme/app_theme.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/updates/providers/update_provider.dart';
import 'features/updates/screens/force_update_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Best-effort init: при ошибках (нет Firebase config и т.п.)
  // приложение продолжает работу без push.
  await NotificationService.init();
  runApp(const ProviderScope(child: CollabNotesApp()));
}

class CollabNotesApp extends ConsumerWidget {
  const CollabNotesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeModeAsync = ref.watch(themeModeProvider);
    final themeMode = themeModeAsync.valueOrNull ?? ThemeMode.system;

    // Проверка обновлений — выполняется один раз при старте.
    final updateCheck = ref.watch(updateCheckProvider);
    final info = updateCheck.valueOrNull;
    final showForceUpdate =
        info != null && info.hasUpdate && info.mandatory;

    if (showForceUpdate) {
      return MaterialApp(
        title: 'Совместные заметки',
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: ForceUpdateScreen(info: info),
      );
    }

    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Совместные заметки',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
