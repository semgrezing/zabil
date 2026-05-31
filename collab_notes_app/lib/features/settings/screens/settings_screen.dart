import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/settings_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/auth/models/auth_models.dart';
import '../../../features/invitations/providers/invitations_provider.dart';
import '../../../features/updates/services/update_service.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/theme/app_dimensions.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/avatar_history_viewer.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeModeAsync = ref.watch(themeModeProvider);
    final authState = ref.watch(authStateProvider);
    final user = authState.valueOrNull?.user;
    final theme = Theme.of(context);
    final currentMode = themeModeAsync.valueOrNull ?? ThemeMode.system;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
        actions: [
          IconButton(
            icon: Icon(_themeIcon(currentMode)),
            tooltip: _themeLabel(currentMode),
            onPressed: () {
              final next = _nextThemeMode(currentMode);
              ref.read(themeModeProvider.notifier).setTheme(next);
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          // User section
          if (user != null) ...[
            ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                backgroundImage: user.avatarResolvedUrl != null
                    ? NetworkImage(user.avatarResolvedUrl!)
                    : null,
                child: user.avatarResolvedUrl == null
                    ? Text(
                        user.displayLabel.isNotEmpty
                            ? user.displayLabel[0].toUpperCase()
                            : user.username[0].toUpperCase(),
                        style: theme.textTheme.titleMedium,
                      )
                    : null,
              ),
              title: Text(user.displayLabel),
              subtitle: Text('@${user.username}', style: theme.textTheme.bodySmall),
              trailing: const Icon(Icons.edit),
              onTap: () => _openProfileEditor(context, ref, user),
            ),
            const Divider(),
            const _SectionHeader(label: 'Уведомления'),
            SwitchListTile.adaptive(
              secondary: const Icon(SolarIconsOutline.notes),
              title: const Text('Пуши по заметкам'),
              subtitle: const Text(
                'Новые и обновлённые заметки в группах',
                style: TextStyle(color: AppColors.fgSoft),
              ),
              value: user.notePushEnabled,
              onChanged: (value) => ref
                  .read(authStateProvider.notifier)
                  .updateNotificationPrefs(notePushEnabled: value),
            ),
            SwitchListTile.adaptive(
              secondary: const Icon(SolarIconsOutline.checkCircle),
              title: const Text('Пуши по чеклистам'),
              subtitle: const Text(
                'Только при полном завершении чеклиста',
                style: TextStyle(color: AppColors.fgSoft),
              ),
              value: user.checklistPushEnabled,
              onChanged: (value) => ref
                  .read(authStateProvider.notifier)
                  .updateNotificationPrefs(checklistPushEnabled: value),
            ),
            SwitchListTile.adaptive(
              secondary: const Icon(SolarIconsOutline.download),
              title: const Text('Пуши новых версий'),
              subtitle: const Text(
                'APK/EXE с прямой ссылкой на скачивание',
                style: TextStyle(color: AppColors.fgSoft),
              ),
              value: user.releasePushEnabled,
              onChanged: (value) => ref
                  .read(authStateProvider.notifier)
                  .updateNotificationPrefs(releasePushEnabled: value),
            ),
            const Divider(),
          ],

          // Invitations & User search
          const _SectionHeader(label: 'Социальное'),
          _InvitationsTile(),
          ListTile(
            leading: const Icon(SolarIconsOutline.magnifier),
            title: const Text('Найти пользователя'),
            subtitle: const Text(
              'Поиск и приглашение в группу',
              style: TextStyle(color: AppColors.fgSoft),
            ),
            trailing: const Icon(SolarIconsOutline.altArrowRight, size: 16),
            onTap: () => context.push('/search'),
          ),
          ListTile(
            leading: const Icon(SolarIconsOutline.clockCircle),
            title: const Text('Активность'),
            subtitle: const Text(
              'Последние действия в группах',
              style: TextStyle(color: AppColors.fgSoft),
            ),
            trailing: const Icon(SolarIconsOutline.altArrowRight, size: 16),
            onTap: () => context.push('/activity'),
          ),

          const Divider(),

          // Update check
          ListTile(
            leading: const Icon(SolarIconsOutline.refresh),
            title: const Text('Проверить обновления'),
            onTap: () => _checkForUpdate(context),
          ),

          // App version
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final version = snapshot.data?.version ?? '...';
              return ListTile(
                leading: const Icon(SolarIconsOutline.infoCircle),
                title: const Text('Версия приложения'),
                subtitle: Text(version),
              );
            },
          ),

          const Divider(),

          // Logout
          ListTile(
            leading: Icon(SolarIconsOutline.logout, color: theme.colorScheme.error),
            title: Text('Выйти', style: TextStyle(color: theme.colorScheme.error)),
            onTap: () => _confirmLogout(context, ref),
          ),
        ],
      ),
    );
  }

  IconData _themeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return SolarIconsOutline.sun;
      case ThemeMode.dark:
        return SolarIconsOutline.moon;
      case ThemeMode.system:
        return SolarIconsOutline.monitor;
    }
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Светлая тема';
      case ThemeMode.dark:
        return 'Тёмная тема';
      case ThemeMode.system:
        return 'Системная тема';
    }
  }

  ThemeMode _nextThemeMode(ThemeMode current) {
    switch (current) {
      case ThemeMode.system:
        return ThemeMode.light;
      case ThemeMode.light:
        return ThemeMode.dark;
      case ThemeMode.dark:
        return ThemeMode.system;
    }
  }

  Future<void> _checkForUpdate(BuildContext context) async {
    try {
      final info = await UpdateService().check();

      if (!context.mounted) return;

      if (info.hasUpdate) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Доступно обновление'),
            content: Text('Доступна версия ${info.latestVersion}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Позже'),
              ),
              if (info.downloadUrl != null)
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await launchUrl(Uri.parse(info.downloadUrl!));
                  },
                  child: const Text('Скачать'),
                ),
            ],
          ),
        );
      } else {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          const SnackBar(content: Text('У вас последняя версия')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          const SnackBar(content: Text('Не удалось проверить обновления')),
        );
      }
    }
  }

  void _openProfileEditor(BuildContext context, WidgetRef ref, UserModel user) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useRootNavigator: true,
      builder: (_) => _EditProfileSheet(user: user),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выйти?'),
        content: const Text('Вы будете разлогинены.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authStateProvider.notifier).logout();
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  final UserModel user;

  const _EditProfileSheet({required this.user});

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  final _nameCtrl = TextEditingController();
  String? _avatarPath;
  String? _serverAvatarUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.user.displayName ?? '';
    _serverAvatarUrl = widget.user.avatarResolvedUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 100,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Кадрирование аватарки',
            cropStyle: CropStyle.circle,
          ),
          IOSUiSettings(
            title: 'Кадрирование аватарки',
            cropStyle: CropStyle.circle,
          ),
        ],
      );

      if (cropped != null && mounted) {
        setState(() => _avatarPath = cropped.path);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось обработать изображение: $e')),
      );
    }
  }

  Future<void> _openAvatarHistory() async {
    final history = await ref.read(authStateProvider.notifier).getAvatarHistory();
    if (!mounted) return;

    final entries = history
        .map(
          (e) => AvatarHistoryEntry(
            id: e['id'] as String,
            imageUrl: _resolveAvatarUrl(e['avatarUrl'] as String?),
            createdAt: DateTime.tryParse((e['createdAt'] ?? '').toString()),
          ),
        )
        .where((e) => e.imageUrl.isNotEmpty)
        .toList();

    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('История аватарок пока пуста')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AvatarHistoryViewer(
          title: 'Аватарки',
          entries: entries,
          canDelete: true,
          onDelete: (entry) async {
            await ref
                .read(authStateProvider.notifier)
                .deleteAvatarHistoryItem(entry.id);
            ref.invalidate(authStateProvider);
          },
        ),
      ),
    );
  }

  Future<void> _deleteCurrentAvatar() async {
    await ref.read(authStateProvider.notifier).deleteAvatar();
    if (!mounted) return;
    setState(() {
      _avatarPath = null;
      _serverAvatarUrl = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Текущая аватарка удалена')),
    );
  }

  String _resolveAvatarUrl(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return '${AppConfig.apiOrigin}$raw';
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final notifier = ref.read(authStateProvider.notifier);
      final currentName = widget.user.displayName?.trim() ?? '';
      final nextName = _nameCtrl.text.trim();

      if (nextName != currentName) {
        await notifier.updateDisplayName(nextName.isEmpty ? null : nextName);
      }
      if (_avatarPath != null) {
        await notifier.uploadAvatar(_avatarPath!);
      }

      if (!mounted) return;
      Navigator.pop(context);
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('Профиль обновлен')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось обновить профиль: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ImageProvider<Object>? avatarProvider = _avatarPath != null
        ? FileImage(File(_avatarPath!))
      : (_serverAvatarUrl != null
        ? NetworkImage(_serverAvatarUrl!)
            : null);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
          top: AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  GestureDetector(
                    onTap: _openAvatarHistory,
                    child: CircleAvatar(
                      radius: 36,
                      backgroundImage: avatarProvider,
                      child: avatarProvider == null
                          ? Text(
                              widget.user.displayLabel.isNotEmpty
                                  ? widget.user.displayLabel[0].toUpperCase()
                                  : widget.user.username[0].toUpperCase(),
                            )
                          : null,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.photo_camera),
                    onPressed: _saving ? null : _pickAvatar,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: _saving ? null : _openAvatarHistory,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('История'),
                ),
                TextButton.icon(
                  onPressed: _saving ? null : _deleteCurrentAvatar,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Удалить'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _nameCtrl,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Имя',
                hintText: 'Как показывать вас другим',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Отмена'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Сохранить'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InvitationsTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitationsAsync = ref.watch(invitationsProvider);
    final count = invitationsAsync.valueOrNull?.length ?? 0;

    return ListTile(
      leading: const Icon(SolarIconsOutline.letter),
      title: const Text('Приглашения'),
      subtitle: Text(
        count > 0 ? '$count новых' : 'Нет новых приглашений',
        style: const TextStyle(color: AppColors.fgSoft),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(width: 4),
          const Icon(SolarIconsOutline.altArrowRight, size: 16),
        ],
      ),
      onTap: () => context.push('/invitations'),
    );
  }
}
