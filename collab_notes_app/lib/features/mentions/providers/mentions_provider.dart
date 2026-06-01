import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/mention_model.dart';
import '../services/mentions_service.dart';
import '../../auth/providers/auth_provider.dart';

final mentionsServiceProvider =
    Provider<MentionsService>((ref) => MentionsService());

final mentionsProvider =
    AsyncNotifierProvider<MentionsNotifier, List<MentionModel>>(
  MentionsNotifier.new,
);

class MentionsNotifier extends AsyncNotifier<List<MentionModel>> {
  MentionsService get _service => ref.read(mentionsServiceProvider);

  @override
  Future<List<MentionModel>> build() async {
    final auth = ref.watch(authStateProvider);
    if (auth.valueOrNull?.isLoggedIn != true) return [];
    return _service.getMentions();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _service.getMentions());
  }

  Future<void> markAllRead() async {
    await _service.markAllRead();
    state = state.whenData(
      (list) => list.map((m) => MentionModel(
        id: m.id,
        context: m.context,
        mentioner: m.mentioner,
        group: m.group,
        note: m.note,
        messageId: m.messageId,
        read: true,
        createdAt: m.createdAt,
      )).toList(),
    );
  }

  void addFromWs(MentionModel mention) {
    state = state.whenData((list) => [mention, ...list]);
  }
}
