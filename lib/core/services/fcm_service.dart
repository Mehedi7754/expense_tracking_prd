import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'push_notification_service.dart';
import 'notification_router.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If the message contains a notification payload, Google Play Services / Android OS
  // has ALREADY automatically rendered it into the system tray!
  // Showing it again via PushNotificationService causes an immediate duplicate.
  if (message.notification != null) {
    debugPrint('[FCM] Notification already rendered by Android system tray: ${message.messageId}');
    return;
  }

  // Only handle data-only messages in background isolate
  try {
    await Firebase.initializeApp();
  } catch (_) {}

  final data = message.data;
  final title = data['title'] ?? 'GW SpendWise Alert';
  final body = data['body'] ?? data['message'] ?? '';
  final type = data['type']?.toString().toLowerCase() ?? 'general';
  final notifId = message.messageId ?? data['notificationId']?.toString();

  try {
    await PushNotificationService.instance.initialize(isBackground: true);
    if (type.contains('expense')) {
      await PushNotificationService.instance.showExpenseAlert(
        title: title,
        body: body,
        expenseId: data['expenseId'] ?? data['relatedExpenseId'],
        notificationId: notifId,
        payload: NotificationRouter.encode(data),
      );
    } else if (type.contains('attendance')) {
      await PushNotificationService.instance.showAttendanceReminder(
        title: title,
        body: body,
        notificationId: notifId,
        payload: NotificationRouter.encode(data),
      );
    } else {
      await PushNotificationService.instance.showImmediate(
        title: title,
        body: body,
        notificationId: notifId,
        payload: NotificationRouter.encode(data),
      );
    }
  } catch (e) {
    debugPrint('[FCM] Background notification display error: $e');
  }
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  bool _initialized = false;
  String? _fcmToken;

  String? get token => _fcmToken;

  static const String _prefKeyFcmToken = 'gw_cached_fcm_token';

  Future<void> initialize() async {
    if (kIsWeb) return;
    if (_initialized) return;

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;

      // Request notification permissions
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('[FCM] Notification authorizationStatus: ${settings.authorizationStatus}');

      // Get initial token
      _fcmToken = await messaging.getToken();
      debugPrint('[FCM] Device Token: $_fcmToken');

      if (_fcmToken != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefKeyFcmToken, _fcmToken!);
        await syncTokenWithBackend(_fcmToken);
      }

      // Listen for token refreshes
      messaging.onTokenRefresh.listen((newToken) async {
        _fcmToken = newToken;
        debugPrint('[FCM] Token refreshed: $newToken');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefKeyFcmToken, newToken);
        await syncTokenWithBackend(newToken);
      });

      // Foreground message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        debugPrint('[FCM] Foreground message received: ${message.messageId}');
        final notification = message.notification;
        final data = message.data;
        final title = notification?.title ?? data['title'] ?? 'GW SpendWise Alert';
        final body = notification?.body ?? data['body'] ?? data['message'] ?? '';
        final type = data['type']?.toString().toLowerCase() ?? 'general';

        final notifId = message.messageId ?? data['notificationId']?.toString();

        if (type.contains('expense')) {
          await PushNotificationService.instance.showExpenseAlert(
            title: title,
            body: body,
            expenseId: data['expenseId'] ?? data['relatedExpenseId'],
            notificationId: notifId,
            payload: NotificationRouter.encode(data),
          );
        } else if (type.contains('attendance')) {
          await PushNotificationService.instance.showAttendanceReminder(
            title: title,
            body: body,
            notificationId: notifId,
            payload: NotificationRouter.encode(data),
          );
        } else {
          await PushNotificationService.instance.showImmediate(
            title: title,
            body: body,
            notificationId: notifId,
            payload: NotificationRouter.encode(data),
          );
        }
      });

      // Tapped a system-tray FCM notification while app was in background
      FirebaseMessaging.onMessageOpenedApp.listen((m) => NotificationRouter.handleData(m.data));

      // App was killed and launched by tapping an FCM notification
      final initial = await messaging.getInitialMessage();
      if (initial != null) NotificationRouter.handleData(initial.data);

      _initialized = true;
    } catch (e, st) {
      debugPrint('[FCM] Initialization error: $e\n$st');
    }
  }

  /// Sends the registered FCM device token to the backend so the server can push to this device.
  Future<void> syncTokenWithBackend([String? explicitToken]) async {
    final tokenToSync = explicitToken ?? _fcmToken;
    if (tokenToSync == null || tokenToSync.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('gw_session_auth_token') ??
          prefs.getString('auth_token') ??
          prefs.getString('access_token');
      if (authToken == null || authToken.isEmpty) {
        debugPrint('[FCM] No auth token found yet; will sync upon login.');
        return;
      }

      final client = ApiClient();
      client.setAuthToken(authToken);

      final response = await client.post(
        ApiEndpoints.resolve('/users/fcm-token'),
        body: {
          'token': tokenToSync,
          'deviceInfo': 'Android',
        },
      );
      debugPrint('[FCM] Successfully registered token with backend: $response');
    } catch (e) {
      debugPrint('[FCM] Exception syncing token: $e');
    }
  }
}
