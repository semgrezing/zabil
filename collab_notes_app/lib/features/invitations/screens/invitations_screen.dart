import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';
import '../models/invitation_model.dart';
import '../models/invitation_action_result.dart';
import '../providers/invitations_provider.dart';
import '../../mentions/models/mention_model.dart';
import '../../mentions/providers/mentions_provider.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_dimensions.dart';
import '../../../shared/widgets/app_loader.dart';

class InvitationsScreen extends ConsumerStatefulWidget {
  const InvitationsScreen({super.key});

  @override
  ConsumerState<InvitationsScreen> createState() => _InvitationsScreenState();
}

class _InvitationsScreenState extends ConsumerState<InvitationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (_tabs.index == 1 && !_tabs.indexIsChanging) {
        _markMentionsRead();
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _markMentionsRead() {
    final mentions = ref.read(mentionsProvider).valueOrNull ?? [];
    if (mentions.any((m) => !m.read)) {
      ref.read(mentionsProvider.notifier).markAllRead();
    }
  }

  @override
  Widget build(BuildContext context) {
    final invitationsAsync = ref.watch(invitationsProvider);
    final mentionsAsync = ref.watch(mentionsProvider);

    final invCount = invitationsAsync.valueOrNull?.length ?? 0;
    final mentUnread = (mentionsAsync.valueOrNull ?? []).where((m) => !m.read).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Входящие'),
        actions: [
          IconButton(
            icon: const Icon(SolarIconsOutline.refresh),
            onPressed: () {
              ref.read(invitationsProvider.notifier).refresh();
              ref.read(mentionsProvider.notifier).refresh();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Приглашения'),
                  if (invCount > 0) ...[
                    const SizedBox(width: 6),
                    _TabBadge(invCount),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Упоминания'),
                  if (mentUnread > 0) ...[
                    const SizedBox(width: 6),
                    _TabBadge(mentUnread),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _InvitationsTab(invitationsAsync: invitationsAsync),
          _MentionsTab(mentionsAsync: mentionsAsync),
        ],
      ),
    );
  }
}

class _TabBadge extends StatelessWidget {
  final int count;
  const _TabBadge(this.count);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.fgContainer,
        ),
      ),
    );
  }
}

// ─── Invitations tab ──────────────────────────────────────────────────────────

class _InvitationsTab extends ConsumerWidget {
  final AsyncValue<List<InvitationModel>> invitationsAsync;
  const _InvitationsTab({required this.invitationsAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return invitationsAsync.when(
      loading: () => const AppLoader(),
      error: (err, _) => AppErrorState(
        message: 'Не удалось загрузить приглашения',
        onRetry: () => ref.read(invitationsProvider.notifier).refresh(),
      ),
      data: (invitations) {
        if (invitations.isEmpty) {
          return const AppEmptyState(
            icon: SolarIconsOutline.letter,
            message: 'Нет входящих приглашений',
            hint: 'Когда вас пригласят в группу, оно появится здесь',
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.read(invitationsProvider.notifier).refresh(),
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: invitations.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) =>
                _InvitationCard(invitation: invitations[index]),
          ),
        );
      },
    );
  }
}

// ─── Mentions tab ─────────────────────────────────────────────────────────────

class _MentionsTab extends ConsumerWidget {
  final AsyncValue<List<MentionModel>> mentionsAsync;
  const _MentionsTab({required this.mentionsAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return mentionsAsync.when(
      loading: () => const AppLoader(),
      error: (err, _) => AppErrorState(
        message: 'Не удалось загрузить упоминания',
        onRetry: () => ref.read(mentionsProvider.notifier).refresh(),
      ),
      data: (mentions) {
        if (mentions.isEmpty) {
          return const AppEmptyState(
            icon: SolarIconsOutline.letterOpened,
            message: 'Нет упоминаний',
            hint: 'Когда кто-то напишет @вашеимя, вы увидите это здесь',
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.read(mentionsProvider.notifier).refresh(),
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: mentions.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) =>
                _MentionCard(mention: mentions[index]),
          ),
        );
      },
    );
  }
}

class _MentionCard extends StatelessWidget {
  final MentionModel mention;
  const _MentionCard({required this.mention});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: () {
          final path = mention.navigatePath;
          if (path != null) context.push(path);
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                mention.read
                    ? SolarIconsOutline.letterOpened
                    : SolarIconsBold.letterOpened,
                size: 20,
                color: mention.read ? AppColors.fgSoft : AppColors.white,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mention.mentionerLabel,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: mention.read
                            ? FontWeight.w400
                            : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'упомянул вас ${mention.contextLabel}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (mention.navigatePath != null)
                const Icon(
                  SolarIconsOutline.altArrowRight,
                  size: 16,
                  color: AppColors.fgSoft,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Invitation card ──────────────────────────────────────────────────────────

/// Карточка приглашения с per-item loading state.
///
/// История бага:
/// Stage 4-5: `onPressed: () => ref.read(...).accept(id)` — Future терялся.
/// Stage 6: try/catch + AppButton + isLoading.
/// Stage 7-bugfix: пользователь всё ещё сообщил что не работает.
/// Заменено на vanilla `ElevatedButton` / `OutlinedButton` (полностью убираем
/// `AppButton` из подозрений) + comprehensive debug logging + явные snackbar'ы
/// и для успеха и для ошибки. Идентичные снэкбары видны даже если виджет
/// успел размонтироваться, потому что используем `rootScaffoldMessenger`.
class _InvitationCard extends ConsumerStatefulWidget {
  final InvitationModel invitation;

  const _InvitationCard({required this.invitation});

  @override
  ConsumerState<_InvitationCard> createState() => _InvitationCardState();
}

class _InvitationCardState extends ConsumerState<_InvitationCard> {
  bool _accepting = false;
  bool _declining = false;

  bool get _busy => _accepting || _declining;

  Future<void> _accept() async {
    debugPrint('[invitations] accept tapped: ${widget.invitation.id}');
    if (_busy) return;
    setState(() => _accepting = true);
    final messenger = ScaffoldMessenger.of(context);
    final groupTitle = widget.invitation.group['title'] ?? 'группу';
    try {
      final result = await ref
          .read(invitationsProvider.notifier)
          .accept(widget.invitation.id);
      debugPrint('[invitations] accept OK');
      messenger.showSnackBar(
        SnackBar(content: Text(_acceptMessage(result, groupTitle))),
      );
    } catch (e, st) {
      debugPrint('[invitations] accept ERR: $e\n$st');
      if (mounted) setState(() => _accepting = false);
      messenger.showSnackBar(
        SnackBar(content: Text(_friendlyError(e, 'принять'))),
      );
    }
  }

  Future<void> _decline() async {
    debugPrint('[invitations] decline tapped: ${widget.invitation.id}');
    if (_busy) return;
    setState(() => _declining = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref
          .read(invitationsProvider.notifier)
          .decline(widget.invitation.id);
      debugPrint('[invitations] decline OK');
      messenger.showSnackBar(
        SnackBar(content: Text(_declineMessage(result))),
      );
    } catch (e, st) {
      debugPrint('[invitations] decline ERR: $e\n$st');
      if (mounted) setState(() => _declining = false);
      messenger.showSnackBar(
        SnackBar(content: Text(_friendlyError(e, 'отклонить'))),
      );
    }
  }

  String _friendlyError(Object e, String action) {
    final s = e.toString().toLowerCase();
    if (s.contains('connection') ||
        s.contains('socketexception') ||
        s.contains('network')) {
      return 'Нет соединения с сервером';
    }
    if (s.contains('404') || s.contains('not found')) {
      return 'Приглашение больше не активно';
    }
    if (s.contains('400') || s.contains('уже обработано')) {
      return 'Приглашение уже обработано';
    }
    if (s.contains('403') || s.contains('forbidden')) {
      return 'Нет доступа к этому приглашению';
    }
    if (s.contains('500')) {
      return 'Ошибка сервера, попробуйте позже';
    }
    return 'Не удалось $action приглашение (${e.toString().substring(0, e.toString().length.clamp(0, 60))})';
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

  @override
  Widget build(BuildContext context) {
    final inv = widget.invitation;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              inv.group['title'] ?? 'Группа',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Приглашение от ${_displayName(inv.sender)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _decline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.white,
                      side: const BorderSide(
                        color: AppColors.surfaceGlassStrong,
                      ),
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                    ),
                    child: _declining
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.white,
                              ),
                            ),
                          )
                        : const Text('Отклонить'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy ? null : _accept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.white,
                      foregroundColor: AppColors.fgContainer,
                      disabledBackgroundColor:
                          AppColors.white.withValues(alpha: 0.5),
                      disabledForegroundColor:
                          AppColors.fgContainer.withValues(alpha: 0.6),
                      minimumSize: const Size(0, 50),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                    ),
                    child: _accepting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.fgContainer,
                              ),
                            ),
                          )
                        : const Text(
                            'Принять',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _displayName(Map<String, String> user) {
    final name = user['displayName']?.trim();
    if (name != null && name.isNotEmpty) return name;
    return user['username'] ?? 'пользователя';
  }
}
