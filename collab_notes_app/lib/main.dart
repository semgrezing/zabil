import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        builder: (context, child) => AppExitGuard(
          child: child ?? const SizedBox.shrink(),
        ),
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
      builder: (context, child) => AppExitGuard(
        child: child ?? const SizedBox.shrink(),
      ),
      routerConfig: router,
    );
  }
}

class AppExitGuard extends StatefulWidget {
  final Widget child;

  const AppExitGuard({super.key, required this.child});

  @override
  State<AppExitGuard> createState() => _AppExitGuardState();
}

class _AppExitGuardState extends State<AppExitGuard> {
  static const _confirmWindow = Duration(seconds: 3);

  DateTime? _lastBackRequestAt;

  Future<void> _handleBack() async {
    final navigator = Navigator.maybeOf(context);
    if (navigator != null) {
      final hasBackStack = navigator.canPop();
      final didPop = await navigator.maybePop();
      if (didPop || hasBackStack) return;
    }

    final now = DateTime.now();
    final withinWindow = _lastBackRequestAt != null &&
        now.difference(_lastBackRequestAt!) <= _confirmWindow;

    if (withinWindow) {
      SystemNavigator.pop();
      return;
    }

    _lastBackRequestAt = now;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Еще раз, чтобы выйти'),
        duration: _confirmWindow,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: widget.child,
    );
  }
}
