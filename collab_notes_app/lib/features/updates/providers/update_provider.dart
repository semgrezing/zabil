import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/update_info.dart';
import '../services/update_service.dart';

final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService());

/// Стартовая проверка апдейта при запуске приложения.
final updateCheckProvider = FutureProvider<UpdateInfo>((ref) async {
  return ref.read(updateServiceProvider).check();
});

/// Состояние процесса скачивания + установки.
class UpdateProgress {
  final double fraction; // 0.0..1.0
  final int received;
  final int total;
  final bool isInstalling;
  final String? error;

  const UpdateProgress({
    this.fraction = 0,
    this.received = 0,
    this.total = 0,
    this.isInstalling = false,
    this.error,
  });

  UpdateProgress copyWith({
    double? fraction,
    int? received,
    int? total,
    bool? isInstalling,
    String? error,
  }) =>
      UpdateProgress(
        fraction: fraction ?? this.fraction,
        received: received ?? this.received,
        total: total ?? this.total,
        isInstalling: isInstalling ?? this.isInstalling,
        error: error,
      );
}

final updateProgressProvider =
    NotifierProvider<UpdateProgressNotifier, UpdateProgress>(
  UpdateProgressNotifier.new,
);

class UpdateProgressNotifier extends Notifier<UpdateProgress> {
  CancelToken? _cancelToken;

  @override
  UpdateProgress build() => const UpdateProgress();

  Future<void> downloadAndInstall(UpdateInfo info) async {
    _cancelToken = CancelToken();
    state = const UpdateProgress();
    try {
      final service = ref.read(updateServiceProvider);

      // iOS: OTA через itms-services, не нужно скачивать файл вручную.
      if (service.isIos) {
        state = state.copyWith(isInstalling: true);
        await service.installViaOta(info);
        return;
      }

      final path = await service.download(
        info,
        cancelToken: _cancelToken,
        onProgress: (fraction, received, total) {
          state = state.copyWith(
            fraction: fraction,
            received: received,
            total: total,
          );
        },
      );
      state = state.copyWith(isInstalling: true);
      await service.install(path);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isInstalling: false);
    }
  }

  void cancel() {
    _cancelToken?.cancel();
  }
}
