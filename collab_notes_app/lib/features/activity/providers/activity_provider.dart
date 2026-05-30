import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity_item.dart';
import '../services/activity_service.dart';
import '../../auth/providers/auth_provider.dart';

final activityServiceProvider = Provider<ActivityService>((ref) => ActivityService());

final activityFeedProvider =
    AsyncNotifierProvider<ActivityFeedNotifier, List<ActivityItem>>(
  ActivityFeedNotifier.new,
);

class ActivityFeedNotifier extends AsyncNotifier<List<ActivityItem>> {
  ActivityService get _service => ref.read(activityServiceProvider);

  @override
  Future<List<ActivityItem>> build() {
    final auth = ref.watch(authStateProvider);
    if (auth.valueOrNull?.isLoggedIn != true) return Future.value([]);
    return _service.getFeed();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _service.getFeed());
  }
}
