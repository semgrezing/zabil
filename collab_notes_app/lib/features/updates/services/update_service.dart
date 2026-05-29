import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/api_endpoints.dart';
import '../../../core/config/app_config.dart';
import '../models/update_info.dart';

/// Сервис проверки и установки обновлений приложения.
///
/// Канал доставки: свой бэкенд (`/update` + статика `/releases/`).
/// Платформы: Android (sideload APK через `open_filex`), Windows (external
/// PowerShell updater script), iOS (OTA manifest plist через itms-services).
class UpdateService {
  final Dio _dio = ApiClient.create();

  Future<UpdateInfo> check() async {
    final platform = _currentPlatform();
    if (platform == null) {
      final pkg = await PackageInfo.fromPlatform();
      return UpdateInfo.none(pkg.version);
    }
    final pkg = await PackageInfo.fromPlatform();
    final currentVersion = pkg.version;

    try {
      final response = await _dio.get(
        ApiEndpoints.update,
        queryParameters: {
          'platform': platform,
          'currentVersion': currentVersion,
        },
        options: Options(
          // Без auth — endpoint публичный
          headers: {'Authorization': null},
        ),
      );
      final data = response.data as Map<String, dynamic>;
      return UpdateInfo.fromJson(data);
    } catch (e) {
      // Не валим запуск из-за проблем с сервером.
      debugPrint('UpdateService.check failed: $e');
      return UpdateInfo.none(currentVersion);
    }
  }

  /// Скачивает дистрибутив с callback прогресса. Возвращает абсолютный
  /// путь к скачанному файлу.
  Future<String> download(
    UpdateInfo info, {
    required void Function(double progress, int received, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    if (info.downloadUrl == null) {
      throw StateError('No downloadUrl in UpdateInfo');
    }

    final dir = await getTemporaryDirectory();
    final platform = _currentPlatform();
    final ext = platform == 'android' ? 'apk' : platform == 'ios' ? 'ipa' : 'exe';
    final fileName = 'collab_notes_${info.latestVersion}.$ext';
    final filePath = '${dir.path}${Platform.pathSeparator}$fileName';

    // Если уже есть файл с этим именем — удаляем (мог быть обрывный download).
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }

    final url = _absoluteUrl(info.downloadUrl!);
    await _dio.download(
      url,
      filePath,
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          onProgress(received / total, received, total);
        }
      },
      options: Options(
        headers: {'Authorization': null},
        receiveTimeout: const Duration(minutes: 10),
      ),
    );

    return filePath;
  }

  /// Запускает установку скачанного дистрибутива.
  ///
  /// Android: открывает APK системным intent.
  /// Windows: пишет batch-updater, запускает его и завершает процесс.
  /// iOS: открывает itms-services:// URL для OTA-установки через manifest.plist.
  Future<void> install(String filePath) async {
    if (Platform.isAndroid) {
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        throw StateError('OpenFilex failed: ${result.message}');
      }
      return;
    }

    if (Platform.isWindows) {
      await _installWindows(filePath);
      return;
    }

    throw UnsupportedError(
      'Установка не поддерживается на ${Platform.operatingSystem}',
    );
  }

  /// iOS OTA: открывает itms-services URL, iOS сам скачает и установит IPA.
  /// Не использует download+install flow — вместо этого вызывается напрямую.
  Future<void> installViaOta(UpdateInfo info) async {
    if (info.manifestUrl == null) {
      throw StateError('No manifestUrl in UpdateInfo for iOS OTA');
    }
    final manifestAbsUrl = _absoluteUrl(info.manifestUrl!);
    final itmUri = Uri.parse(
      'itms-services://?action=download-manifest&url=$manifestAbsUrl',
    );
    if (!await launchUrl(itmUri, mode: LaunchMode.externalApplication)) {
      throw StateError('Could not launch itms-services URL');
    }
  }

  /// Windows updater pattern: запускаем external .bat который ждёт пока
  /// текущий процесс закроется, копирует новый exe поверх старого и стартует.
  Future<void> _installWindows(String newExePath) async {
    final currentExe = Platform.resolvedExecutable;
    final pid = pid_; // dart:io pid
    final tempDir = await getTemporaryDirectory();
    final updaterBat =
        '${tempDir.path}${Platform.pathSeparator}collab_notes_updater.bat';

    // Bat-скрипт:
    //  1) Ждёт 3 сек чтобы текущий процесс точно завершился
    //  2) Копирует новый exe поверх старого
    //  3) Стартует обновлённое приложение
    //  4) Удаляет временный exe и сам себя
    final batContent = '''
@echo off
timeout /t 3 /nobreak >nul
:wait
tasklist /FI "PID eq $pid" 2>nul | find "$pid" >nul
if not errorlevel 1 (
  timeout /t 1 /nobreak >nul
  goto wait
)
copy /Y "$newExePath" "$currentExe" >nul
start "" "$currentExe"
del "$newExePath" 2>nul
(goto) 2>nul & del "%~f0"
''';

    await File(updaterBat).writeAsString(batContent);

    // Запускаем updater detached и закрываем приложение.
    await Process.start(
      'cmd',
      ['/c', 'start', '', '/B', updaterBat],
      mode: ProcessStartMode.detached,
      runInShell: true,
    );

    // Дать миллисекунду на старт скрипта и выходим
    await Future<void>.delayed(const Duration(milliseconds: 300));
    exit(0);
  }

  bool get isIos => Platform.isIOS;

  String? _currentPlatform() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isWindows) return 'windows';
    if (Platform.isIOS) return 'ios';
    return null;
  }

  String _absoluteUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    // Относительный путь от backend → префиксуем origin'ом.
    return '${AppConfig.apiOrigin}$url';
  }
}

// Сокращение для dart:io.pid (чтобы не путать с локальной переменной).
int get pid_ => pid;
