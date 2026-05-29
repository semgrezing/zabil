import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/groups_provider.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../core/config/app_config.dart';

class GroupDetailScreen extends ConsumerWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);

    return groupsAsync.when(
      loading: () => const Scaffold(body: AppLoader()),
      error: (err, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Ошибка: $err')),
      ),
      data: (groups) {
        final group = groups.where((g) => g.id == groupId).firstOrNull;
        if (group == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Группа не найдена')),
          );
        }

        return Scaffold(
          appBar: AppBar(title: Text(group.title)),
          body: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: group.members.length,
            itemBuilder: (context, index) {
              final member = group.members[index];
              final avatarUrl = _resolveAvatar(member.avatarUrl);
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? Text(member.displayLabel[0].toUpperCase())
                      : null,
                ),
                title: Text(member.displayLabel),
                trailing: _roleChip(context, member.role),
              );
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('Заметки группы'),
            onPressed: () => context.go('/notes?groupId=$groupId'),
          ),
        );
      },
    );
  }

  Widget _roleChip(BuildContext context, String role) {
    final labels = {'owner': 'Создатель', 'admin': 'Админ', 'member': 'Участник'};
    return Chip(
      label: Text(labels[role] ?? role, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
    );
  }

  String? _resolveAvatar(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return '${AppConfig.apiOrigin}$trimmed';
  }
}
