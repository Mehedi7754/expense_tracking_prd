import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'push_notification_service.dart';
import 'notification_router.dart';
import 'realtime_sync_service.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized in this background isolate.
  try {
    await Firebase.initializeApp();
  } catch (_) {}

  // Always initialize PushNotificationService so we can show the notification
  // on the correct Android channel with proper priority/sound/vibration.
  // Note: even when message.notification != null, Android may show a default
  // notification but it won't use the app's custom channel — we show our own
  // to ensure the channel, icon, and routing payload are correct.
  try {
    await PushNotificationService.instance.initialize(isBackground: true);
  } catch (_) {}

  final data = message.data;
  final notification = message.notification;

  // Extract title/body from notification payload first, then fall back to data fields
  final title = notification?.title ?? data['title'] ?? 'GW SpendWise Alert';
  final body = notification?.body ?? data['body'] ?? data['message'] ?? '';
  final type = data['type']?.toString().toLowerCase() ?? 'general';
  final notifId = message.messageId ?? data['notificationId']?.toString();

  debugPrint('[FCM-BG] Background message: type=$type, title=$title, id=$notifId');

  try {
    if (type.contains('chat')) {
      await PushNotificationService.instance.showChatAlert(
        title: title,
        body: body,
        channelId: (data['channelId'] ?? '').toString(),
        notificationId: notifId,
        payload: NotificationRouter.encode(data),
      );
    } else if (type.contains('expense')) {
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
    } else if (type.contains('registration') || type.contains('employee')) {
      // Registration notifications are ADMIN-ONLY: check stored user role
      bool isAdmin = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        final userJson = prefs.getString('gw_session_user_data') ?? '';
        isAdmin = userJson.contains('"role":"mainAdmin"') ||
            userJson.contains('"role": "mainAdmin"');
      } catch (_) {}
      if (isAdmin) {
        await PushNotificationService.instance.showEmployeeRegistrationAlert(
          title: title,
          body: body,
          notificationId: notifId,
          payload: NotificationRouter.encode(data),
        );
      }
    } else {
      await PushNotificationService.instance.showImmediate(
        title: title,
        body: body,
        channel: 'high_importance_channel',
        notificationId: notifId,
        payload: NotificationRouter.encode(data),
      );
    }
  } catch (e) {
    debugPrint('[FCM-BG] Background notification display error: $e');
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
      // Firebase.initializeApp() was already called in main() before runApp.
      // Try again here safely in case initialize() is called independently.
      try {
        await Firebase.initializeApp();
      } catch (_) {}
      // onBackgroundMessage is already registered in main() — do NOT re-register here.

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

        // Immediately trigger reactive sync across all providers
        RealtimeSyncService.instance.triggerImmediateSync(
          type: type,
          payload: data,
        );

        if (type.contains('chat')) {
          await PushNotificationService.instance.showChatAlert(
            title: title,
            body: body,
            channelId: (data['channelId'] ?? '').toString(),
            notificationId: notifId,
            payload: NotificationRouter.encode(data),
          );
        } else if (type.contains('expense')) {
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
        } else if (type.contains('registration') || type.contains('employee')) {
          // Registration notifications are ADMIN-ONLY: check stored user role
          bool isAdmin = false;
          try {
            final prefs = await SharedPreferences.getInstance();
            final userJson = prefs.getString('gw_session_user_data') ?? '';
            isAdmin = userJson.contains('"role":"mainAdmin"') ||
                userJson.contains('"role": "mainAdmin"');
          } catch (_) {}
          if (isAdmin) {
            await PushNotificationService.instance.showEmployeeRegistrationAlert(
              title: title,
              body: body,
              notificationId: notifId,
              payload: NotificationRouter.encode(data),
            );
          }
        } else {
          await PushNotificationService.instance.showImmediate(
            title: title,
            body: body,
            channel: 'high_importance_channel',
            notificationId: notifId,
            payload: NotificationRouter.encode(data),
          );
        }
      });

      // Tapped a system-tray FCM notification while app was in background
      FirebaseMessaging.onMessageOpenedApp.listen((m) {
        RealtimeSyncService.instance.triggerImmediateSync(
          type: m.data['type']?.toString(),
          payload: m.data,
        );
        NotificationRouter.handleData(m.data);
      });

      // App was killed and launched by tapping an FCM notification
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        RealtimeSyncService.instance.triggerImmediateSync(
          type: initial.data['type']?.toString(),
          payload: initial.data,
        );
        NotificationRouter.handleData(initial.data);
      }

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

      try {
        final response = await client.post(
          ApiEndpoints.resolve('/users/fcm-token'),
          body: {
            'token': tokenToSync,
            'deviceInfo': defaultTargetPlatform.name,
          },
        );
        debugPrint('[FCM] Successfully registered token with backend: $response');
      } catch (err) {
        try {
          final response = await client.post(
            ApiEndpoints.resolve('/notifications/fcm-token'),
            body: {
              'token': tokenToSync,
              'deviceInfo': defaultTargetPlatform.name,
            },
          );
          debugPrint('[FCM] Successfully registered token via notifications endpoint: $response');
        } catch (e2) {
          debugPrint('[FCM] Exception syncing token: $err / $e2');
        }
      }
    } catch (e) {
      debugPrint('[FCM] Failed to sync token with backend: $e');
    }
  }
}
