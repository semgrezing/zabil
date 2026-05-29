import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/invitations_provider.dart';
import '../models/invitation_action_result.dart';
import '../../../shared/widgets/app_loader.dart';

class InvitationsScreen extends ConsumerWidget {
  const InvitationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitationsAsync = ref.watch(invitationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Приглашения'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => ref.read(invitationsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: invitationsAsync.when(
        loading: () => const AppLoader(),
        error: (err, _) => Center(child: Text('Ошибка: $err')),
        data: (invitations) {
          if (invitations.isEmpty) {
            return const Center(
              child: Text(
                'Нет входящих приглашений',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(invitationsProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: invitations.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final inv = invitations[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inv.group['title'] ?? 'Группа',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Приглашение от ${_displayName(inv.sender)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.6),
                              ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  try {
                                    final result = await ref
                                        .read(invitationsProvider.notifier)
                                        .decline(inv.id);
                                    messenger.showSnackBar(
                                      SnackBar(content: Text(_declineMessage(result))),
                                    );
                                  } catch (_) {
                                    messenger.showSnackBar(
                                      const SnackBar(content: Text('Не удалось отклонить приглашение')),
                                    );
                                  }
                                },
                                child: const Text('Отклонить'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  final groupTitle = inv.group['title'] ?? 'группу';
                                  try {
                                    final result = await ref
                                        .read(invitationsProvider.notifier)
                                        .accept(inv.id);
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(_acceptMessage(result, groupTitle)),
                                      ),
                                    );
                                  } catch (_) {
                                    messenger.showSnackBar(
                                      const SnackBar(content: Text('Не удалось принять приглашение')),
                                    );
                                  }
                                },
                                child: const Text('Принять'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _acceptMessage(InvitationActionResult result, String groupTitle) {
    if (result.status == 'accepted') {
      if (result.alreadyProcessed) {
        return 'Вы уже вступили в «$groupTitle»';
      }
      return 'Вы вступили в «$groupTitle»';
    }
    if (result.status == 'declined') {
      return 'Приглашение уже отклонено';
    }
    return 'Приглашение обработано';
  }

  String _declineMessage(InvitationActionResult result) {
    if (result.status == 'declined') {
      if (result.alreadyProcessed) {
        return 'Приглашение уже отклонено';
      }
      return 'Приглашение отклонено';
    }
    if (result.status == 'accepted') {
      return 'Приглашение уже принято';
    }
    return 'Приглашение обработано';
  }

  String _displayName(Map<String, String> user) {
    final name = user['displayName']?.trim();
    if (name != null && name.isNotEmpty) return name;
    return user['username'] ?? 'пользователя';
  }
}
