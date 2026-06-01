import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import '../providers/settings_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/auth/models/auth_models.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/api_endpoints.dart';
import '../../../features/groups/providers/groups_provider.dart';
import 'package:image_picker/image_picker.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeModeAsync = ref.watch(themeModeProvider);
    final authState = ref.watch(authStateProvider);
    final user = authState.valueOrNull?.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        children: [
          // User section
          if (user != null) ...[
            ListTile(
              leading: CircleAvatar(
                backgroundImage: user.avatarResolvedUrl != null
                    ? NetworkImage(user.avatarResolvedUrl!)
                    : null,
                child: user.avatarResolvedUrl == null
                    ? Text(
                        user.displayLabel.isNotEmpty
                            ? user.displayLabel[0].toUpperCase()
                            : user.username[0].toUpperCase(),
                      )
                    : null,
              ),
              title: Text(user.displayLabel),
              subtitle: Text('@${user.username}'),
              trailing: const Icon(Icons.edit),
              onTap: () => _openProfileEditor(context, ref, user),
            ),
            const Divider(),
          ],

          // Groups section
          ListTile(
            leading: const Icon(Icons.group_outlined),
            title: const Text('Создать группу'),
            onTap: () => _showCreateGroupDialog(context, ref),
          ),

          _GroupsManagedSection(),

          const Divider(),

          // Theme section
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('Тема', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          themeModeAsync.whenOrNull(
            data: (mode) => Column(
              children: [
                _ThemeOption(
                  label: 'Системная',
                  value: ThemeMode.system,
                  current: mode,
                  onChanged: (m) => ref.read(themeModeProvider.notifier).setTheme(m),
                ),
                _ThemeOption(
                  label: 'Светлая',
                  value: ThemeMode.light,
                  current: mode,
                  onChanged: (m) => ref.read(themeModeProvider.notifier).setTheme(m),
                ),
                _ThemeOption(
                  label: 'Тёмная',
                  value: ThemeMode.dark,
                  current: mode,
                  onChanged: (m) => ref.read(themeModeProvider.notifier).setTheme(m),
                ),
              ],
            ),
          ) ??
              const SizedBox.shrink(),

          const Divider(),

          // Update check
          ListTile(
            leading: const Icon(Icons.system_update_outlined),
            title: const Text('Проверить обновления'),
            onTap: () => _checkForUpdate(context),
          ),

          // App version
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final version = snapshot.data?.version ?? '...';
              return ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Версия приложения'),
                subtitle: Text(version),
              );
            },
          ),

          const Divider(),

          // Logout
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Выйти', style: TextStyle(color: Colors.red)),
            onTap: () => _confirmLogout(context, ref),
          ),
        ],
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Создать группу'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Название группы'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await ref.read(groupsProvider.notifier).createGroup(ctrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkForUpdate(BuildContext context) async {
    try {
      final dio = ApiClient.create();
      final response = await dio.get(ApiEndpoints.update);
      final serverVersion = response.data['version'] as String;
      final downloadUrl = response.data['downloadUrl'] as String;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (!context.mounted) return;

      if (_isNewer(serverVersion, currentVersion)) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('🎉 Доступно обновление'),
            content: Text('Новая версия: $serverVersion\nТекущая: $currentVersion'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Позже'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await launchUrl(Uri.parse(downloadUrl));
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
      builder: (_) => _EditProfileSheet(user: user),
    );
  }

  bool _isNewer(String serverVersion, String currentVersion) {
    final parse = (String v) => v.split('.').map(int.parse).toList();
    final server = parse(serverVersion);
    final current = parse(currentVersion);
    for (var i = 0; i < 3; i++) {
      final s = i < server.length ? server[i] : 0;
      final c = i < current.length ? current[i] : 0;
      if (s > c) return true;
      if (s < c) return false;
    }
    return false;
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выйти?'),
        content: const Text('Вы будете разлогинены.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
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

class _ThemeOption extends StatelessWidget {
  final String label;
  final ThemeMode value;
  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeOption({
    required this.label,
    required this.value,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<ThemeMode>(
      title: Text(label),
      value: value,
      groupValue: current,
      onChanged: (v) => v != null ? onChanged(v) : null,
      dense: true,
    );
  }
}

class _GroupsManagedSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);

    return groupsAsync.whenOrNull(
          data: (groups) => groups.isEmpty
              ? const SizedBox.shrink()
              : ExpansionTile(
                  leading: const Icon(Icons.groups_outlined),
                  title: const Text('Мои группы'),
                  children: groups
                      .map(
                        (g) => ListTile(
                          contentPadding: const EdgeInsets.only(left: 56, right: 16),
                          title: Text(g.title),
                          subtitle: Text('${g.members.length} участников'),
                          trailing: const Icon(Icons.chevron_right, size: 16),
                          onTap: () {
                            // Open group invite dialog
                            _showInviteDialog(context, ref, g.id, g.title);
                          },
                        ),
                      )
                      .toList(),
                ),
        ) ??
        const SizedBox.shrink();
  }

  void _showInviteDialog(
      BuildContext context, WidgetRef ref, String groupId, String groupTitle) {
    final ctrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Пригласить в «$groupTitle»'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Имя пользователя'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              try {
                final dio = ApiClient.create();
                await dio.post('/api/v1/invitations',
                    data: {'groupId': groupId, 'username': ctrl.text.trim()});
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Приглашение отправлено @${ctrl.text.trim()}')),
                  );
                }
              } on DioException catch (e) {
                if (ctx.mounted) {
                  final msg = e.response?.data?['error'] ?? 'Ошибка';
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(msg as String)));
                }
              }
            },
            child: const Text('Пригласить'),
          ),
        ],
      ),
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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.user.displayName ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _avatarPath = picked.path);
    }
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
        : (widget.user.avatarResolvedUrl != null
            ? NetworkImage(widget.user.avatarResolvedUrl!)
            : null);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
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
                IconButton(
                  icon: const Icon(Icons.photo_camera),
                  onPressed: _saving ? null : _pickAvatar,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Имя',
              hintText: 'Как показывать вас другим',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
              ),
              const SizedBox(width: 12),
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
    );
  }
}
