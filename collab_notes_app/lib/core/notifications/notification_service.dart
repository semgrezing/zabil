import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';
import '../api/api_client.dart';
import '../config/api_endpoints.dart';
import '../realtime/ws_client.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static String? _fcmToken;
  static StreamSubscription? _wsSub;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (Platform.isWindows) {
      await localNotifier.setup(appName: 'Совместные заметки');
    } else {
      await _initLocal();
    }

    if (!Platform.isAndroid && !Platform.isIOS) {
      debugPrint('NotificationService: skipping Firebase on ${Platform.operatingSystem}');
      return;
    }

    try {
      await Firebase.initializeApp();
      await _initFcm();
    } catch (e) {
      debugPrint('NotificationService: Firebase init failed: $e');
    }
  }

  static Future<void> _initLocal() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _local.initialize(initSettings);

    if (Platform.isAndroid) {
      final androidImpl = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
    }
  }

  static void listenToWsEvents(WsClient wsClient) {
    _wsSub?.cancel();
    if (Platform.isAndroid || Platform.isIOS) return;
    _wsSub = wsClient.events
        .where((e) => e is PushNotificationEvent)
        .cast<PushNotificationEvent>()
        .listen((e) {
      showLocal(title: e.title, body: e.body, payload: e.data['route'] as String?);
    });
  }

  static void stopWsListener() {
    _wsSub?.cancel();
    _wsSub = null;
  }

  static Future<void> _initFcm() async {
    final messaging = FirebaseMessaging.instance;

    // Разрешение iOS (Android получает автоматически если manifest правильный)
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    _fcmToken = await messaging.getToken();
    debugPrint('FCM token: ${_fcmToken?.substring(0, 16)}...');

    // Foreground messages → показываем local notification
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // BG handler регистрируется через top-level функцию (см. ниже)
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    // Реакция на смену токена (refresh)
    messaging.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      registerWithBackend();
    });
  }

  /// POST `/devices/register` с текущим FCM-токеном. Вызывается после
  /// успешного login и при refresh токена.
  static Future<void> registerWithBackend() async {
    if (_fcmToken == null) return;
    final dio = ApiClient.create();
    try {
      await dio.post(
        ApiEndpoints.registerDevice,
        data: {
          'platform': Platform.isAndroid
              ? 'android'
              : Platform.isIOS
                  ? 'ios'
                  : Platform.operatingSystem,
          'token': _fcmToken,
        },
      );
    } catch (e) {
      debugPrint('NotificationService: register failed: $e');
    }
  }

  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    final notif = message.notification;
    if (notif == null) return;
    final details = Platform.isIOS
        ? const NotificationDetails(
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          )
        : const NotificationDetails(
            android: AndroidNotificationDetails(
              'collab_notes_default',
              'Совместные заметки',
              channelDescription: 'Основной канал уведомлений',
              importance: Importance.high,
              priority: Priority.high,
            ),
          );
    await _local.show(
      message.hashCode,
      notif.title ?? 'Уведомление',
      notif.body ?? '',
      details,
      payload: message.data['route'] as String?,
    );
  }

  static Future<void> showLocal({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (Platform.isWindows) {
      final notification = LocalNotification(
        title: title,
        body: body,
      );
      notification.show();
      return;
    }

    final details = Platform.isAndroid
        ? const NotificationDetails(
            android: AndroidNotificationDetails(
              'collab_notes_default',
              'Совместные заметки',
              importance: Importance.high,
              priority: Priority.high,
            ),
          )
        : Platform.isIOS
            ? const NotificationDetails(
                iOS: DarwinNotificationDetails(
                  presentAlert: true,
                  presentBadge: true,
                  presentSound: true,
                ),
              )
            : const NotificationDetails();

    await _local.show(
      DateTime.now().millisecondsSinceEpoch.remainder(1 << 30),
      title,
      body,
      details,
      payload: payload,
    );
  }
}

/// Top-level handler для background FCM сообщений. Должна быть top-level
/// функцией (требование Firebase Messaging).
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  // BG-handler работает в isolated context — Firebase нужно инициализировать
  // заново.
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  debugPrint('BG message: ${message.notification?.title}');
}
