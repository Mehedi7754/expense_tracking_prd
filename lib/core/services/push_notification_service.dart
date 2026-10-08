import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'notification_router.dart';

/// Service for OS-level push notifications (Android status bar + iOS tray).
/// Works without Firebase — uses flutter_local_notifications for local triggers.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Notification channel IDs
  static const String _channelExpenses = 'expenses_channel';
  static const String _channelAttendance = 'attendance_channel';
  static const String _channelGeneral = 'general_channel';

  Future<void> initialize({bool isBackground = false}) async {
    // Only supported on mobile — web uses browser notification API (not implemented here)
    if (kIsWeb) return;

    try {
      tz.initializeTimeZones();
    } catch (_) {}

    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channels (skip permission dialog in background service)
    await _createAndroidChannels(requestPermission: !isBackground);

    _initialized = true;

    // App cold-started by tapping a local notification -> route to its page
    if (!isBackground) {
      try {
        final launch = await _plugin.getNotificationAppLaunchDetails();
        if (launch?.didNotificationLaunchApp == true) {
          NotificationRouter.handlePayload(launch!.notificationResponse?.payload);
        }
      } catch (_) {}
    }
  }

  /// Attendance reminders are for employees ONLY. Admin/finance/viewer never get them.
  Future<void> syncAttendanceReminders({
    required bool isEmployee,
    int morningHour = 9,
    int cutoffHour = 13,
  }) async {
    if (!_initialized || kIsWeb) return;
    if (!isEmployee) {
      await _plugin.cancel(1);
      await _plugin.cancel(2);
      return;
    }
    String fmtH(int h) => '${(h % 12 == 0 ? 12 : h % 12).toString().padLeft(2, '0')}:00 ${h < 12 ? 'AM' : 'PM'}';
    await scheduleDailyAttendanceReminder(
      id: 1,
      title: '📍 Morning Check-in',
      body: 'Morning check-in is open (after ${fmtH(morningHour)}).',
      hour: morningHour,
      minute: 0,
    );
    await scheduleDailyAttendanceReminder(
      id: 2,
      title: '📍 Afternoon Check-in',
      body: 'Afternoon check-in is open (after ${fmtH(cutoffHour)}).',
      hour: cutoffHour,
      minute: 0,
    );
  }

  Future<void> _createAndroidChannels({bool requestPermission = true}) async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    if (requestPermission) {
      try {
        await androidPlugin.requestNotificationsPermission();
      } catch (e) {
        debugPrint('[PushNotificationService] requestNotificationsPermission: $e');
      }
    }

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelExpenses,
        'Expense Notifications',
        description: 'Alerts for expense submissions, approvals, and rejections',
        importance: Importance.high,
        playSound: true,
      ),
    );

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelAttendance,
        'Attendance Reminders',
        description: 'Daily attendance check-in reminders and late alerts',
        importance: Importance.high,
        playSound: true,
      ),
    );

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelGeneral,
        'General Notifications',
        description: 'Budget warnings, salary, payroll, and other alerts',
        importance: Importance.high,
        playSound: true,
      ),
    );

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'high_importance_channel',
        'Important Notifications',
        description: 'High priority alerts and push notifications',
        importance: Importance.high,
        playSound: true,
      ),
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    NotificationRouter.handlePayload(response.payload);
  }

  final Set<String> _deliveredNotificationIds = <String>{};

  /// Show an immediate notification in the OS status bar / notification tray.
  Future<void> showImmediate({
    required String title,
    required String body,
    String channel = _channelGeneral,
    String? payload,
    String? notificationId,
  }) async {
    if (!_initialized || kIsWeb) return;

    if (notificationId != null && notificationId.isNotEmpty) {
      if (_deliveredNotificationIds.contains(notificationId)) {
        return; // Already notified the user
      }
      _deliveredNotificationIds.add(notificationId);
      // Keep set bounded to last 200 items
      if (_deliveredNotificationIds.length > 200) {
        _deliveredNotificationIds.remove(_deliveredNotificationIds.first);
      }
    }

    final id = notificationId != null && notificationId.hashCode != 0
        ? notificationId.hashCode.abs() % 100000
        : DateTime.now().millisecondsSinceEpoch % 100000;

    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          _channelName(channel),
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/launcher_icon',
          enableVibration: true,
          playSound: true,
          tag: notificationId,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  /// Show expense-specific notification (high importance channel).
  Future<void> showExpenseAlert({
    required String title,
    required String body,
    String? expenseId,
    String? notificationId,
    String? payload,
  }) async {
    await showImmediate(
      title: title,
      body: body,
      channel: _channelExpenses,
      payload: payload ?? (expenseId != null ? 'expense:$expenseId' : null),
      notificationId: notificationId,
    );
  }

  /// Show attendance-specific notification (high importance channel).
  Future<void> showAttendanceReminder({
    required String title,
    required String body,
    String? notificationId,
    String? payload,
  }) async {
    await showImmediate(
      title: title,
      body: body,
      channel: _channelAttendance,
      notificationId: notificationId,
      payload: payload ?? 'type=attendance',
    );
  }

  /// Schedule a daily attendance reminder.
  /// [id] must be unique per schedule (e.g. 1 for morning, 2 for afternoon).
  Future<void> scheduleDailyAttendanceReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        _nextInstanceOfTime(hour, minute),
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelAttendance,
            'Attendance Reminders',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/launcher_icon',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'type=attendance',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // repeat daily at same time
      );
    } catch (e) {
      debugPrint('[PushNotificationService] scheduleDailyAttendanceReminder error: $e');
    }
  }

  /// Cancel a specific scheduled notification.
  Future<void> cancel(int id) async {
    if (!_initialized || kIsWeb) return;
    await _plugin.cancel(id);
  }

  /// Cancel ALL scheduled and shown notifications.
  Future<void> cancelAll() async {
    if (!_initialized || kIsWeb) return;
    await _plugin.cancelAll();
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  String _channelName(String channelId) {
    switch (channelId) {
      case _channelExpenses:
        return 'Expense Notifications';
      case _channelAttendance:
        return 'Attendance Reminders';
      default:
        return 'General Notifications';
    }
  }
}
