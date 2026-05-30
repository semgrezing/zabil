import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_dimensions.dart';
import '../../../shared/widgets/app_loader.dart';
import '../models/chat_message.dart';
import '../providers/chats_provider.dart';
import 'chat_image_viewer_screen.dart';

/// Универсальный экран чата.
///
/// Один из трёх режимов:
/// - group: `groupId` задан, `noteId` = null → чат группы
/// - note:  `groupId` + `noteId` → чат заметки (filtered view)
/// - personal: `userId` задан → 1:1 чат
class ChatScreen extends ConsumerStatefulWidget {
  final String? groupId;
  final String? noteId;
  final String? userId;
  final String title;
  final String? subtitle;

  const ChatScreen({
    super.key,
    this.groupId,
    this.noteId,
    this.userId,
    required this.title,
    this.subtitle,
  }) : assert(groupId != null || userId != null);

  bool get _isGroup => groupId != null;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Mark-as-read для личного чата при открытии
    if (widget.userId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(personalChatProvider(widget.userId!).notifier)
            .markRead();
      });
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (widget._isGroup) {
        await ref
            .read(groupChatProvider(GroupChatKey(widget.groupId!, widget.noteId))
                .notifier)
            .send(body: text);
      } else {
        await ref
            .read(personalChatProvider(widget.userId!).notifier)
            .send(body: text);
      }
      _inputCtrl.clear();
      // Список рендерится reverse=true, новое сообщение в начале —
      // прокручиваем к началу списка (визуально вниз).
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось отправить: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendImages() async {
    if (_sending) return;

    final picker = ImagePicker();
    final files = await picker.pickMultiImage();
    if (files.isEmpty) return;

    final compressed = await _askCompressionMode();
    if (compressed == null) return;

    setState(() => _sending = true);
    try {
      final service = ref.read(chatsServiceProvider);
      String? textToAttach = _inputCtrl.text.trim();
      for (var i = 0; i < files.length; i++) {
        final upload = await service.uploadChatImage(
          files[i].path,
          compressed: compressed,
        );

        if (widget._isGroup) {
          await ref
              .read(groupChatProvider(GroupChatKey(widget.groupId!, widget.noteId)).notifier)
              .send(
                body: i == 0 && textToAttach.isNotEmpty ? textToAttach : null,
                imageUrl: upload['url'] as String?,
                imageMimeType: upload['mimeType'] as String?,
                imageSize: (upload['fileSize'] as num?)?.toInt(),
                imageCompressed: upload['compressed'] as bool?,
              );
        } else {
          await ref.read(personalChatProvider(widget.userId!).notifier).send(
                body: i == 0 && textToAttach.isNotEmpty ? textToAttach : null,
                imageUrl: upload['url'] as String?,
                imageMimeType: upload['mimeType'] as String?,
                imageSize: (upload['fileSize'] as num?)?.toInt(),
                imageCompressed: upload['compressed'] as bool?,
              );
        }
      }
      _inputCtrl.clear();
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отправить изображения: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<bool?> _askCompressionMode() {
    return showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(SolarIconsOutline.gallery),
              title: const Text('Отправить со сжатием'),
              subtitle: const Text('Быстрее отправка, меньше размер'),
              onTap: () => Navigator.of(ctx).pop(true),
            ),
            ListTile(
              leading: const Icon(SolarIconsOutline.gallery),
              title: const Text('Отправить без сжатия'),
              subtitle: const Text('Оригинальное качество'),
              onTap: () => Navigator.of(ctx).pop(false),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title),
            if (widget.subtitle != null)
              Text(
                widget.subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
        actions: [
          if (widget.noteId != null && widget.groupId != null)
            IconButton(
              icon: const Icon(SolarIconsOutline.chatRound),
              tooltip: 'Открыть чат группы',
              onPressed: () {
                context.push(
                  '/chats/group/${widget.groupId}?title=${Uri.encodeComponent(widget.subtitle ?? 'Группа')}',
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessages(context)),
          SafeArea(top: false, child: _buildComposer(context)),
        ],
      ),
    );
  }

  Widget _buildMessages(BuildContext context) {
    final currentUserId =
        ref.watch(authStateProvider).valueOrNull?.user?.id;

    if (widget._isGroup) {
      final key = GroupChatKey(widget.groupId!, widget.noteId);
      final async = ref.watch(groupChatProvider(key));
      return async.when(
        loading: () => const AppLoader(),
        error: (e, _) => Center(child: Text('Ошибка загрузки: $e')),
        data: (messages) => _renderGroup(context, messages, currentUserId),
      );
    } else {
      final async = ref.watch(personalChatProvider(widget.userId!));
      return async.when(
        loading: () => const AppLoader(),
        error: (e, _) => Center(child: Text('Ошибка загрузки: $e')),
        data: (messages) => _renderPersonal(context, messages, currentUserId),
      );
    }
  }

  Widget _renderGroup(
    BuildContext context,
    List<GroupChatMessage> messages,
    String? meId,
  ) {
    if (messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Сообщений пока нет. Напишите первым.',
            style: TextStyle(color: AppColors.fgSoft),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      reverse: true,
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final m = messages[i];
        final mine = m.senderId == meId;
        return _MessageBubble(
          body: m.body,
          imageUrl: _resolveImageUrl(m.imageUrl),
          time: m.createdAt,
          mine: mine,
          authorName: mine ? null : _displayName(m.sender),
          noteTitle: m.noteTitle,
          noteColorLabel: m.noteColorLabel,
          onNoteTap: (m.noteId != null && widget.noteId == null)
              ? () => context.push(
                    '/chats/note/${m.noteId}?groupId=${widget.groupId}&title=${Uri.encodeComponent(m.noteTitle ?? 'Заметка')}&groupTitle=${Uri.encodeComponent(widget.title)}',
                  )
              : null,
        );
      },
    );
  }

  Widget _renderPersonal(
    BuildContext context,
    List<PersonalChatMessage> messages,
    String? meId,
  ) {
    if (messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Начните диалог — напишите первое сообщение.',
            style: TextStyle(color: AppColors.fgSoft),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      reverse: true,
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final m = messages[i];
        final mine = m.senderId == meId;
        return _MessageBubble(
          body: m.body,
          imageUrl: _resolveImageUrl(m.imageUrl),
          time: m.createdAt,
          mine: mine,
          authorName: null,
        );
      },
    );
  }

  Widget _buildComposer(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(SolarIconsOutline.gallery),
            tooltip: 'Изображения',
            onPressed: _sending ? null : _pickAndSendImages,
          ),
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(
                hintText: 'Сообщение',
                filled: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppColors.white,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _sending ? null : _send,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.fgContainer,
                        ),
                      )
                    : const Icon(
                        SolarIconsBold.plain,
                        color: AppColors.fgContainer,
                        size: 20,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _resolveImageUrl(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return '${AppConfig.apiOrigin}$raw';
  }
}

String _displayName(Map<String, String> user) {
  final name = user['displayName']?.trim();
  if (name != null && name.isNotEmpty) return name;
  return user['username'] ?? '?';
}

class _MessageBubble extends StatelessWidget {
  final String body;
  final String? imageUrl;
  final DateTime time;
  final bool mine;
  final String? authorName;
  final String? noteTitle;
  final String? noteColorLabel;
  final VoidCallback? onNoteTap;

  const _MessageBubble({
    required this.body,
    required this.imageUrl,
    required this.time,
    required this.mine,
    required this.authorName,
    this.noteTitle,
    this.noteColorLabel,
    this.onNoteTap,
  });

  bool get _isImageOnly => imageUrl != null && body.trim().isEmpty;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('HH:mm');
    final bg = mine ? AppColors.white : AppColors.bg2;
    final fg = mine ? AppColors.fgContainer : AppColors.white;
    final parsedNoteColor = _safeColor(noteColorLabel);

    if (_isImageOnly) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment:
              mine ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                child: Column(
                  crossAxisAlignment:
                      mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (authorName != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4, left: 4),
                        child: Text(
                          authorName!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.fgSoft.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ChatImageViewerScreen(imageUrl: imageUrl!),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        child: Image.network(
                          imageUrl!,
                          width: 220,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 220,
                            height: 120,
                            color: AppColors.bg2,
                            alignment: Alignment.center,
                            child:
                                const Icon(SolarIconsOutline.galleryRemove),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Text(
                        formatter.format(time.toLocal()),
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.fgSoft.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (noteTitle != null)
                      GestureDetector(
                        onTap: onNoteTap,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: parsedNoteColor?.withValues(alpha: 0.18) ??
                                fg.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: parsedNoteColor ?? fg.withValues(alpha: 0.7),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                noteTitle!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: fg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (authorName != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          authorName!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: fg.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    if (body.trim().isNotEmpty)
                      Text(
                        body,
                        style: TextStyle(color: fg, fontSize: 15),
                      ),
                    if (imageUrl != null) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatImageViewerScreen(imageUrl: imageUrl!),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                          child: Image.network(
                            imageUrl!,
                            width: 220,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 220,
                              height: 120,
                              color: fg.withValues(alpha: 0.12),
                              alignment: Alignment.center,
                              child: const Icon(SolarIconsOutline.galleryRemove),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      formatter.format(time.toLocal()),
                      style: TextStyle(
                        fontSize: 10,
                        color: fg.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color? _safeColor(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return Color(int.parse(raw.replaceFirst('#', '0xFF')));
    } catch (_) {
      return null;
    }
  }
}
