import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/realtime/ws_client.dart';
import '../../groups/models/group_model.dart';
import '../../groups/services/groups_service.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_dimensions.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../shared/widgets/typing_indicator.dart';
import '../models/chat_message.dart';
import '../models/chat_user_profile.dart';
import '../../../core/utils/error_mapper.dart';
import '../providers/chats_provider.dart';
import 'chat_image_viewer_screen.dart';
import 'chat_user_profile_screen.dart';

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
  final _composerFocusNode = FocusNode();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  bool _showScrollToBottom = false;
  StreamSubscription<WsEvent>? _wsSub;
  GroupModel? _groupMeta;
  final Map<String, _TypingUser> _typingUsers = {};
  Timer? _typingDebounce;

  // Composer handles its own bottom padding (keyboard + safe area)
  static const double _composerHorizontalGap = 12;
  static const double _composerListInset = 120;

  // Personal chat peer profile (avatar, online status)
  ChatUserProfile? _peerProfile;

  static bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  bool get _isTopLevelGroupChat => widget.groupId != null && widget.noteId == null;
  bool get _hasComposerText => _inputCtrl.text.trim().isNotEmpty;

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
    _scrollCtrl.addListener(_onScroll);
    _subscribeWsEvents();
    _loadGroupMeta();
    // Mark-as-read и загрузка профиля для личного чата при открытии
    if (widget.userId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(personalChatProvider(widget.userId!).notifier)
            .markRead();
        _loadPeerProfile();
      });
    }
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _typingDebounce?.cancel();
    for (final entry in _typingUsers.values) {
      entry.timer.cancel();
    }
    _inputCtrl.dispose();
    _composerFocusNode.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _subscribeWsEvents() {
    final ws = ref.read(wsClientProvider);
    final me = ref.read(authStateProvider).valueOrNull?.user?.id;
    _wsSub = ws.events.listen((event) {
      // Online status updates for peer in personal chat
      if (event is UserOnlineStatusEvent && widget.userId == event.userId) {
        if (!mounted) return;
        setState(() {
          _peerProfile = _peerProfile?.copyWith(
            isOnline: event.isOnline,
            lastSeenAt: event.lastSeenAt ?? _peerProfile?.lastSeenAt,
          );
        });
      }
      if (event is ChatTypingEvent) {
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
      } else if (event is ChatStoppedTypingEvent) {
        if (event.kind == 'group' && widget.groupId != null) {
          final data = event.data;
          if (data['groupId']?.toString() != widget.groupId) return;
          final senderId = data['senderId']?.toString();
          if (senderId == null || senderId == me) return;
          _removeTyping(senderId);
        }
        if (event.kind == 'personal' && widget.userId != null) {
          final data = event.data;
          final senderId = data['senderId']?.toString();
          if (senderId == null || senderId == me || senderId != widget.userId) return;
          _removeTyping(senderId);
        }
      }
    });
  }

  void _removeTyping(String userId) {
    _typingUsers[userId]?.timer.cancel();
    if (!mounted) return;
    setState(() => _typingUsers.remove(userId));
  }

  void _sendTypingStop() {
    final ws = ref.read(wsClientProvider);
    if (widget.groupId != null) {
      ws.sendChatTypingStopGroup(widget.groupId!);
    } else if (widget.userId != null) {
      ws.sendChatTypingStopPersonal(widget.userId!);
    }
  }

  Future<void> _loadPeerProfile() async {
    if (widget.userId == null) return;
    try {
      final service = ref.read(chatsServiceProvider);
      final profile = await service.getUserProfile(widget.userId!);
      if (!mounted) return;
      setState(() => _peerProfile = profile);
    } catch (_) {
      // noop: avatar/online indicator simply won't show if unavailable
    }
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

  void _onScroll() {
    // In a reverse list, offset 0 = bottom (newest messages).
    // Show button when scrolled more than ~200px away from the bottom.
    final show = _scrollCtrl.hasClients && _scrollCtrl.offset > 200;
    if (show != _showScrollToBottom) {
      setState(() => _showScrollToBottom = show);
    }
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _openSystemEmojiKeyboard() async {
    _composerFocusNode.requestFocus();
    await SystemChannels.textInput.invokeMethod('TextInput.show');
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    HapticFeedback.lightImpact();
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
        SnackBar(content: Text('Не удалось отправить: ${mapError(e)}')),
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
        SnackBar(content: Text('Не удалось отправить изображения: ${mapError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmDeleteGroupMessage(BuildContext ctx, String groupId, String messageId) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Удалить сообщение?'),
        content: const Text('Сообщение будет удалено для всех.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(true), child: const Text('Удалить')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        final service = ref.read(chatsServiceProvider);
        await service.deleteGroupMessage(groupId, messageId);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Не удалось удалить: ${mapError(e)}')),
          );
        }
      }
    }
  }

  Future<void> _confirmDeletePersonalMessage(BuildContext ctx, String otherUserId, String messageId) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Удалить сообщение?'),
        content: const Text('Сообщение будет удалено для всех.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(true), child: const Text('Удалить')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        final service = ref.read(chatsServiceProvider);
        await service.deletePersonalMessage(otherUserId, messageId);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Не удалось удалить: ${mapError(e)}')),
          );
        }
      }
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

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    // Personal 1:1 chat — show avatar + name + online status
    if (widget.userId != null) {
      return AppBar(
        titleSpacing: 4,
        title: GestureDetector(
          onTap: () => context.push('/users/${widget.userId}'),
          child: Row(
            children: [
              _PeerAvatarWithDot(
                profile: _peerProfile,
                title: widget.title,
                resolveUrl: _resolveImageUrl,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, overflow: TextOverflow.ellipsis),
                    _PeerOnlineSubtitle(profile: _peerProfile),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Group / note chat — original layout
    return AppBar(
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
          if (_groupHintLabel != null)
            Text(
              _groupHintLabel!,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      extendBody: true,
      body: _wrapWithPasteHandler(
        child: Stack(
          children: [
            Positioned.fill(child: _buildMessages(context)),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TypingStrip(label: _typingLabel),
                  _buildComposer(context),
                ],
              ),
            ),
            // Scroll-to-bottom FAB
            if (_showScrollToBottom)
              Positioned(
                right: 16,
                bottom: 100,
                child: Material(
                  color: AppColors.bg2,
                  shape: const CircleBorder(),
                  elevation: 4,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _scrollToBottom,
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Handle Ctrl+V paste on desktop: check clipboard for image bytes.
  Future<void> _handleDesktopPaste() async {
    if (_sending || !_isDesktop) return;
    try {
      final imageBytes = await Pasteboard.image;
      if (imageBytes == null || imageBytes.isEmpty) return;
      await _sendPastedImage(imageBytes);
    } catch (_) {
      // Clipboard did not contain an image — let TextField handle as text.
    }
  }

  /// Upload and send raw image bytes obtained from clipboard paste.
  Future<void> _sendPastedImage(Uint8List imageBytes) async {
    if (_sending) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final service = ref.read(chatsServiceProvider);
      String mimeType = 'image/png';
      String filename = 'pasted_image.png';
      if (imageBytes.length >= 3 &&
          imageBytes[0] == 0xFF &&
          imageBytes[1] == 0xD8 &&
          imageBytes[2] == 0xFF) {
        mimeType = 'image/jpeg';
        filename = 'pasted_image.jpg';
      } else if (imageBytes.length >= 4 &&
          imageBytes[0] == 0x52 &&
          imageBytes[1] == 0x49 &&
          imageBytes[2] == 0x46 &&
          imageBytes[3] == 0x46) {
        mimeType = 'image/webp';
        filename = 'pasted_image.webp';
      }
      final upload = await service.uploadChatImageFromBytes(
        imageBytes,
        compressed: true,
        filename: filename,
        contentType: mimeType,
      );
      final textToAttach = _inputCtrl.text.trim();
      if (widget._isGroup) {
        await ref
            .read(groupChatProvider(GroupChatKey(widget.groupId!, widget.noteId)).notifier)
            .send(
              body: textToAttach.isNotEmpty ? textToAttach : null,
              imageUrl: upload['url'] as String?,
              imageMimeType: upload['mimeType'] as String?,
              imageSize: (upload['fileSize'] as num?)?.toInt(),
              imageCompressed: upload['compressed'] as bool?,
            );
      } else {
        await ref.read(personalChatProvider(widget.userId!).notifier).send(
              body: textToAttach.isNotEmpty ? textToAttach : null,
              imageUrl: upload['url'] as String?,
              imageMimeType: upload['mimeType'] as String?,
              imageSize: (upload['fileSize'] as num?)?.toInt(),
              imageCompressed: upload['compressed'] as bool?,
            );
      }
      _inputCtrl.clear();
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Не удалось отправить изображение: ${mapError(e)}')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// On desktop, wrap the body with a Focus widget that intercepts Ctrl+V
  /// and checks the clipboard for image content before the TextField handles it.
  Widget _wrapWithPasteHandler({required Widget child}) {
    if (!_isDesktop) return child;
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyV &&
            HardwareKeyboard.instance.isControlPressed) {
          _handleDesktopPaste();
        }
        // Always return ignored so the TextField still receives normal
        // keyboard input (including text paste when clipboard has no image).
        return KeyEventResult.ignored;
      },
      child: child,
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
        error: (e, _) => Center(child: Text(mapError(e))),
        data: (messages) => _renderGroup(context, messages, currentUserId),
      );
    } else {
      final async = ref.watch(personalChatProvider(widget.userId!));
      return async.when(
        loading: () => const AppLoader(),
        error: (e, _) => Center(child: Text(mapError(e))),
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
    // Build items list with date separators (list is reverse=true)
    // messages[0] = newest, messages[n-1] = oldest
    final items = <Widget>[];
    for (var i = 0; i < messages.length; i++) {
      final m = messages[i];
      final mine = m.senderId == meId;
      items.add(_MessageBubble(
        body: m.body,
        imageUrl: _resolveImageUrl(m.imageUrl),
        time: m.createdAt,
        mine: mine,
        isDeleted: m.isDeleted,
        authorName: mine ? null : _displayName(m.sender),
        noteTitle: m.noteTitle,
        noteColorLabel: m.noteColorLabel,
        onNoteTap: (m.noteId != null && widget.noteId == null)
            ? () => context.push(
                  '/chats/note/${m.noteId}?groupId=${widget.groupId}&title=${Uri.encodeComponent(m.noteTitle ?? 'Заметка')}&groupTitle=${Uri.encodeComponent(widget.title)}',
                )
            : null,
        onDelete: mine && !m.isDeleted
            ? () => _confirmDeleteGroupMessage(context, widget.groupId!, m.id)
            : null,
      ));
      // Add separator between this message and the next older message
      if (i + 1 < messages.length) {
        final curr = m.createdAt.toLocal();
        final next = messages[i + 1].createdAt.toLocal();
        if (curr.year != next.year || curr.month != next.month || curr.day != next.day) {
          items.add(_DateSeparator(date: curr));
        }
      } else {
        // Add separator before the oldest message
        items.add(_DateSeparator(date: m.createdAt.toLocal()));
      }
    }
    return ListView.builder(
      controller: _scrollCtrl,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 80),
      itemCount: items.length,
      itemBuilder: (context, i) => items[i],
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
    final items = <Widget>[];
    for (var i = 0; i < messages.length; i++) {
      final m = messages[i];
      final mine = m.senderId == meId;
      items.add(_MessageBubble(
        body: m.body,
        imageUrl: _resolveImageUrl(m.imageUrl),
        time: m.createdAt,
        mine: mine,
        isDeleted: m.isDeleted,
        authorName: null,
        onDelete: mine && !m.isDeleted
            ? () => _confirmDeletePersonalMessage(context, widget.userId!, m.id)
            : null,
      ));
      if (i + 1 < messages.length) {
        final curr = m.createdAt.toLocal();
        final next = messages[i + 1].createdAt.toLocal();
        if (curr.year != next.year || curr.month != next.month || curr.day != next.day) {
          items.add(_DateSeparator(date: curr));
        }
      } else {
        items.add(_DateSeparator(date: m.createdAt.toLocal()));
      }
    }
    return ListView.builder(
      controller: _scrollCtrl,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 80),
      itemCount: items.length,
      itemBuilder: (context, i) => items[i],
    );
  }

  Widget _buildComposer(BuildContext context) {
    final hasText = _inputCtrl.text.trim().isNotEmpty;
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final bottomPad = keyboard > 0 ? keyboard + 8 : media.padding.bottom + 8;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPad),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.bg2.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Gallery button
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: IconButton(
                    icon: const Icon(SolarIconsOutline.gallery, size: 20),
                    color: AppColors.fgSoft,
                    tooltip: 'Изображения',
                    onPressed: _sending ? null : _pickAndSendImages,
                  ),
                ),
                // Ghost text field
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    focusNode: _composerFocusNode,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                    style: const TextStyle(color: AppColors.white, fontSize: 15),
                    cursorColor: AppColors.white,
                    onSubmitted: (_) => _send(),
                    onChanged: (value) {
                      final nowHasText = value.trim().isNotEmpty;
                      if (nowHasText != hasText) setState(() {});

                      if (!nowHasText) {
                        _typingDebounce?.cancel();
                        _typingDebounce = null;
                        _sendTypingStop();
                        return;
                      }

                      final ws = ref.read(wsClientProvider);
                      if (widget.groupId != null) {
                        ws.sendChatTypingGroup(widget.groupId!);
                      } else if (widget.userId != null) {
                        ws.sendChatTypingPersonal(widget.userId!);
                      }

                      _typingDebounce?.cancel();
                      _typingDebounce = Timer(const Duration(seconds: 2), () {
                        _typingDebounce = null;
                        _sendTypingStop();
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: 'Сообщение...',
                      hintStyle: TextStyle(color: AppColors.fgSoft, fontSize: 15),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                      isDense: true,
                      filled: false,
                    ),
                  ),
                ),
                // Right: mic (empty) or send (text)
                Padding(
                  padding: const EdgeInsets.only(right: 4, bottom: 2),
                  child: hasText
                      ? Material(
                          color: AppColors.white,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _sending ? null : _send,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: _sending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.fgContainer,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.arrow_upward_rounded,
                                      color: AppColors.fgContainer,
                                      size: 20,
                                    ),
                            ),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.mic_outlined, size: 20),
                          color: AppColors.fgSoft,
                          tooltip: 'Голосовое сообщение (скоро)',
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Голосовые сообщения — скоро'),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
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
  final bool isDeleted;
  final VoidCallback? onDelete;

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
    this.isDeleted = false,
    this.onDelete,
  });

  bool get _isImageOnly => imageUrl != null && body.trim().isEmpty;

  @override
  Widget build(BuildContext context) {
    if (isDeleted) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.bg2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.fgSoft.withValues(alpha: 0.2)),
              ),
              child: Text(
                'Сообщение удалено',
                style: TextStyle(
                  color: AppColors.fgSoft.withValues(alpha: 0.6),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final formatter = DateFormat('HH:mm');
    final bg = mine ? AppColors.white : AppColors.bg2;
    final fg = mine ? AppColors.fgContainer : AppColors.white;
    final parsedNoteColor = _safeColor(noteColorLabel);
    final hasOutsideStatus = deliveryStatus != null;
    return GestureDetector(
      onLongPress: (mine && onDelete != null) ? onDelete : null,
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (mine && hasOutsideStatus) ...[
            _outsideDeliveryIndicator(),
            const SizedBox(width: 6),
          ],
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
          if (!mine && hasOutsideStatus) ...[
            const SizedBox(width: 6),
            _outsideDeliveryIndicator(),
          ],
        ],
      ),
    ));
  }

  Widget _outsideDeliveryIndicator() {
    final status = deliveryStatus;
    if (status == null) return const SizedBox.shrink();

    return SizedBox(
      width: 14,
      height: 14,
      child: Icon(
        status == _MessageDeliveryStatus.read
            ? Icons.done_all_rounded
            : Icons.done_rounded,
        size: 13,
        color: status == _MessageDeliveryStatus.read
            ? AppColors.success
            : AppColors.fgSoft,
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

class _DateSeparator extends StatelessWidget {
  final DateTime date;

  const _DateSeparator({required this.date});

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);

    if (d == today) return 'Сегодня';
    if (d == yesterday) return 'Вчера';

    final year = date.year;
    final month = _monthName(date.month);
    final day = date.day;

    if (year == now.year) return '$day $month';
    return '${day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.$year';
  }

  String _monthName(int month) {
    const names = [
      '', 'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
    ];
    return names[month];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.bg2.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _label(),
            style: const TextStyle(
              color: AppColors.fgSoft,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Typing strip ───────────────────────────────────────────────────────────

class _TypingStrip extends StatelessWidget {
  final String? label;

  const _TypingStrip({required this.label});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.5),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: label == null
            ? const SizedBox.shrink(key: ValueKey('empty'))
            : Container(
                key: const ValueKey('typing'),
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const TypingIndicator(dotSize: 5),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.fgSoft,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────────

class _TypingUser {
  final String name;
  final Timer timer;

  _TypingUser({required this.name, required this.timer});
}

enum _MessageDeliveryStatus { sent, read }

// ─── Personal chat AppBar helpers ───────────────────────────────────────────

class _PeerAvatarWithDot extends StatelessWidget {
  final ChatUserProfile? profile;
  final String title;
  final String? Function(String?) resolveUrl;

  const _PeerAvatarWithDot({
    required this.profile,
    required this.title,
    required this.resolveUrl,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = resolveUrl(profile?.avatarUrl);
    final initials = (profile?.displayLabel ?? title).isNotEmpty
        ? (profile?.displayLabel ?? title)[0].toUpperCase()
        : '?';

    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: avatarUrl == null
                ? Text(initials, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))
                : null,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: (profile?.isOnline ?? false)
                    ? const Color(0xFF4CAF50)
                    : Colors.grey,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeerOnlineSubtitle extends StatelessWidget {
  final ChatUserProfile? profile;

  const _PeerOnlineSubtitle({required this.profile});

  @override
  Widget build(BuildContext context) {
    final subtitleStyle = TextStyle(
      fontSize: 11,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
    );

    if (profile == null) {
      return const SizedBox.shrink();
    }

    if (profile!.isOnline) {
      return Text(
        'В сети',
        style: subtitleStyle.copyWith(color: const Color(0xFF4CAF50)),
      );
    }

    final lastSeen = profile!.lastSeenAt;
    if (lastSeen == null) {
      return Text('Не в сети', style: subtitleStyle);
    }

    final diff = DateTime.now().difference(lastSeen);
    final String ago;
    if (diff.inMinutes < 1) {
      ago = 'только что';
    } else if (diff.inMinutes < 60) {
      ago = '${diff.inMinutes} мин назад';
    } else if (diff.inHours < 24) {
      ago = '${diff.inHours} ч назад';
    } else {
      ago = '${diff.inDays} ${_daysLabel(diff.inDays)} назад';
    }

    return Text('Был(а) $ago', style: subtitleStyle);
  }

  static String _daysLabel(int d) {
    if (d % 10 == 1 && d % 100 != 11) return 'день';
    if (d % 10 >= 2 && d % 10 <= 4 && (d % 100 < 10 || d % 100 >= 20)) return 'дня';
    return 'дней';
  }
}
