import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/realtime/ws_client.dart';
import '../../groups/models/group_model.dart';
import '../../groups/services/groups_service.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_dimensions.dart';
import '../../../shared/widgets/app_loader.dart';
import '../models/chat_message.dart';
import '../providers/chats_provider.dart';
import 'chat_image_viewer_screen.dart';
import 'chat_user_profile_screen.dart';

/// ╨г╨╜╨╕╨▓╨╡╤А╤Б╨░╨╗╤М╨╜╤Л╨╣ ╤Н╨║╤А╨░╨╜ ╤З╨░╤В╨░.
///
/// ╨Ю╨┤╨╕╨╜ ╨╕╨╖ ╤В╤А╤С╤Е ╤А╨╡╨╢╨╕╨╝╨╛╨▓:
/// - group: `groupId` ╨╖╨░╨┤╨░╨╜, `noteId` = null тЖТ ╤З╨░╤В ╨│╤А╤Г╨┐╨┐╤Л
/// - note:  `groupId` + `noteId` тЖТ ╤З╨░╤В ╨╖╨░╨╝╨╡╤В╨║╨╕ (filtered view)
/// - personal: `userId` ╨╖╨░╨┤╨░╨╜ тЖТ 1:1 ╤З╨░╤В
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
  StreamSubscription<WsEvent>? _wsSub;
  GroupModel? _groupMeta;
  final Map<String, _TypingUser> _typingUsers = {};

  bool get _isTopLevelGroupChat => widget.groupId != null && widget.noteId == null;

  String? get _groupHintLabel {
    if (!_isTopLevelGroupChat) return widget.subtitle;
    final count = _groupMeta?.members.length;
    if (count == null) return widget.subtitle;
    return '$count участников';
  }

  String? get _typingLabel {
    if (_typingUsers.isEmpty) return null;
    final names = _typingUsers.values.map((t) => t.name).toList()..sort();
    if (names.length == 1) {
      return '${names.first} печатает...';
    }
    return '${names.join(', ')} печатают...';
  }

  @override
  void initState() {
    super.initState();
    _subscribeTyping();
    _loadGroupMeta();
    // Mark-as-read ╨┤╨╗╤П ╨╗╨╕╤З╨╜╨╛╨│╨╛ ╤З╨░╤В╨░ ╨┐╤А╨╕ ╨╛╤В╨║╤А╤Л╤В╨╕╨╕
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
    _wsSub?.cancel();
    for (final entry in _typingUsers.values) {
      entry.timer.cancel();
    }
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _subscribeTyping() {
    final ws = ref.read(wsClientProvider);
    final me = ref.read(authStateProvider).valueOrNull?.user?.id;
    _wsSub = ws.events.listen((event) {
      if (event is! ChatTypingEvent) return;
      if (event.kind == 'group' && widget.groupId != null) {
        final data = event.data;
        if (data['groupId']?.toString() != widget.groupId) return;
        final senderId = data['senderId']?.toString();
        if (senderId == null || senderId == me) return;
        final displayName = data['displayName']?.toString();
        _upsertTyping(senderId, (displayName == null || displayName.isEmpty) ? 'Пользователь' : displayName);
      }
      if (event.kind == 'personal' && widget.userId != null) {
        final data = event.data;
        final senderId = data['senderId']?.toString();
        if (senderId == null || senderId == me || senderId != widget.userId) return;
        final displayName = data['displayName']?.toString();
        _upsertTyping(senderId, (displayName == null || displayName.isEmpty) ? 'Собеседник' : displayName);
      }
    });
  }

  Future<void> _loadGroupMeta() async {
    if (widget.groupId == null) return;
    try {
      final group = await GroupsService().getGroupById(widget.groupId!);
      if (!mounted) return;
      setState(() => _groupMeta = group);
    } catch (_) {
      // noop: keep existing subtitle when metadata unavailable
    }
  }

  void _upsertTyping(String userId, String name) {
    _typingUsers[userId]?.timer.cancel();
    final timer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _typingUsers.remove(userId);
      });
    });
    if (!mounted) return;
    setState(() {
      _typingUsers[userId] = _TypingUser(name: name, timer: timer);
    });
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
      // ╨б╨┐╨╕╤Б╨╛╨║ ╤А╨╡╨╜╨┤╨╡╤А╨╕╤В╤Б╤П reverse=true, ╨╜╨╛╨▓╨╛╨╡ ╤Б╨╛╨╛╨▒╤Й╨╡╨╜╨╕╨╡ ╨▓ ╨╜╨░╤З╨░╨╗╨╡ тАФ
      // ╨┐╤А╨╛╨║╤А╤Г╤З╨╕╨▓╨░╨╡╨╝ ╨║ ╨╜╨░╤З╨░╨╗╤Г ╤Б╨┐╨╕╤Б╨║╨░ (╨▓╨╕╨╖╤Г╨░╨╗╤М╨╜╨╛ ╨▓╨╜╨╕╨╖).
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('╨Э╨╡ ╤Г╨┤╨░╨╗╨╛╤Б╤М ╨╛╤В╨┐╤А╨░╨▓╨╕╤В╤М: $e')),
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
        SnackBar(content: Text('╨Э╨╡ ╤Г╨┤╨░╨╗╨╛╤Б╤М ╨╛╤В╨┐╤А╨░╨▓╨╕╤В╤М ╨╕╨╖╨╛╨▒╤А╨░╨╢╨╡╨╜╨╕╤П: $e')),
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
              title: const Text('╨Ю╤В╨┐╤А╨░╨▓╨╕╤В╤М ╤Б╨╛ ╤Б╨╢╨░╤В╨╕╨╡╨╝'),
              subtitle: const Text('╨С╤Л╤Б╤В╤А╨╡╨╡ ╨╛╤В╨┐╤А╨░╨▓╨║╨░, ╨╝╨╡╨╜╤М╤И╨╡ ╤А╨░╨╖╨╝╨╡╤А'),
              onTap: () => Navigator.of(ctx).pop(true),
            ),
            ListTile(
              leading: const Icon(SolarIconsOutline.gallery),
              title: const Text('╨Ю╤В╨┐╤А╨░╨▓╨╕╤В╤М ╨▒╨╡╨╖ ╤Б╨╢╨░╤В╨╕╤П'),
              subtitle: const Text('╨Ю╤А╨╕╨│╨╕╨╜╨░╨╗╤М╨╜╨╛╨╡ ╨║╨░╤З╨╡╤Б╤В╨▓╨╛'),
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
            if (widget.groupId != null)
              GestureDetector(
                onTap: () => context.push('/groups/${widget.groupId}'),
                child: Text(widget.title),
              )
            else
              Text(widget.title),
            if ((_typingLabel != null && _isTopLevelGroupChat) || _groupHintLabel != null)
              Text(
                (_typingLabel != null && _isTopLevelGroupChat)
                    ? _typingLabel!
                    : _groupHintLabel!,
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
              tooltip: '╨Ю╤В╨║╤А╤Л╤В╤М ╤З╨░╤В ╨│╤А╤Г╨┐╨┐╤Л',
              onPressed: () {
                context.push(
                  '/chats/group/${widget.groupId}?title=${Uri.encodeComponent(widget.subtitle ?? '╨У╤А╤Г╨┐╨┐╨░')}',
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessages(context)),
          if (_typingLabel != null && !_isTopLevelGroupChat)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Text(
                _typingLabel!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.fgSoft,
                ),
              ),
            ),
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
        error: (e, _) => Center(child: Text('╨Ю╤И╨╕╨▒╨║╨░ ╨╖╨░╨│╤А╤Г╨╖╨║╨╕: $e')),
        data: (messages) => _renderGroup(context, messages, currentUserId),
      );
    } else {
      final async = ref.watch(personalChatProvider(widget.userId!));
      return async.when(
        loading: () => const AppLoader(),
        error: (e, _) => Center(child: Text('╨Ю╤И╨╕╨▒╨║╨░ ╨╖╨░╨│╤А╤Г╨╖╨║╨╕: $e')),
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
            '╨б╨╛╨╛╨▒╤Й╨╡╨╜╨╕╨╣ ╨┐╨╛╨║╨░ ╨╜╨╡╤В. ╨Э╨░╨┐╨╕╤И╨╕╤В╨╡ ╨┐╨╡╤А╨▓╤Л╨╝.',
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
          authorTap: mine
              ? null
              : () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatUserProfileScreen(userId: m.senderId),
                    ),
                  );
                },
          noteTitle: m.noteTitle,
          noteColorLabel: m.noteColorLabel,
          onNoteTap: (m.noteId != null && widget.noteId == null)
              ? () => context.push(
                    '/chats/note/${m.noteId}?groupId=${widget.groupId}&title=${Uri.encodeComponent(m.noteTitle ?? '╨Ч╨░╨╝╨╡╤В╨║╨░')}&groupTitle=${Uri.encodeComponent(widget.title)}',
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
            '╨Э╨░╤З╨╜╨╕╤В╨╡ ╨┤╨╕╨░╨╗╨╛╨│ тАФ ╨╜╨░╨┐╨╕╤И╨╕╤В╨╡ ╨┐╨╡╤А╨▓╨╛╨╡ ╤Б╨╛╨╛╨▒╤Й╨╡╨╜╨╕╨╡.',
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
          deliveryStatus: mine
              ? (m.readAt != null ? _MessageDeliveryStatus.read : _MessageDeliveryStatus.sent)
              : null,
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
            tooltip: '╨Ш╨╖╨╛╨▒╤А╨░╨╢╨╡╨╜╨╕╤П',
            onPressed: _sending ? null : _pickAndSendImages,
          ),
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              onChanged: (value) {
                if (value.trim().isEmpty) return;
                final ws = ref.read(wsClientProvider);
                if (widget.groupId != null) {
                  ws.sendChatTypingGroup(widget.groupId!);
                } else if (widget.userId != null) {
                  ws.sendChatTypingPersonal(widget.userId!);
                }
              },
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(
                hintText: '╨б╨╛╨╛╨▒╤Й╨╡╨╜╨╕╨╡',
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
  final VoidCallback? authorTap;
  final _MessageDeliveryStatus? deliveryStatus;
  final String? noteTitle;
  final String? noteColorLabel;
  final VoidCallback? onNoteTap;

  const _MessageBubble({
    required this.body,
    required this.imageUrl,
    required this.time,
    required this.mine,
    required this.authorName,
    this.authorTap,
    this.deliveryStatus,
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
                        child: GestureDetector(
                          onTap: authorTap,
                          child: Text(
                            authorName!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.fgSoft.withValues(alpha: 0.75),
                            ),
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
                      child: _metaRow(
                        formatter: formatter,
                        fg: AppColors.fgSoft.withValues(alpha: 0.7),
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
                        child: GestureDetector(
                          onTap: authorTap,
                          child: Text(
                            authorName!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: fg.withValues(alpha: 0.75),
                            ),
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
                    _metaRow(
                      formatter: formatter,
                      fg: fg.withValues(alpha: 0.65),
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

  Widget _metaRow({
    required DateFormat formatter,
    required Color fg,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formatter.format(time.toLocal()),
          style: TextStyle(
            fontSize: 10,
            color: fg,
          ),
        ),
        if (mine && deliveryStatus != null) ...[
          const SizedBox(width: 6),
          Icon(
            deliveryStatus == _MessageDeliveryStatus.read
                ? Icons.done_all_rounded
                : Icons.done_rounded,
            size: 12,
            color: deliveryStatus == _MessageDeliveryStatus.read
                ? AppColors.success
                : fg,
          ),
          const SizedBox(width: 4),
          Text(
            deliveryStatus == _MessageDeliveryStatus.read
                ? 'Прочитано'
                : 'Отправлено',
            style: TextStyle(fontSize: 10, color: fg),
          ),
        ],
      ],
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

class _TypingUser {
  final String name;
  final Timer timer;

  _TypingUser({required this.name, required this.timer});
}

enum _MessageDeliveryStatus { sent, read }
