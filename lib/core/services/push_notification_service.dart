import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

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

  Future<void> initialize() async {
    // Only supported on mobile — web uses browser notification API (not implemented here)
    if (kIsWeb) return;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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

    // Create Android notification channels
    await _createAndroidChannels();

    _initialized = true;
  }

  Future<void> _createAndroidChannels() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

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
        importance: Importance.defaultImportance,
        playSound: true,
      ),
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Deep link routing could be handled here if needed
    debugPrint('[Push] Notification tapped: ${response.payload}');
  }

  /// Show an immediate notification in the OS status bar / notification tray.
  Future<void> showImmediate({
    required String title,
    required String body,
    String channel = _channelGeneral,
    String? payload,
  }) async {
    if (!_initialized || kIsWeb) return;

    final id = DateTime.now().millisecondsSinceEpoch % 100000;

    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          _channelName(channel),
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
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
  }) async {
    await showImmediate(
      title: title,
      body: body,
      channel: _channelExpenses,
      payload: expenseId != null ? 'expense:$expenseId' : null,
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
    if (!_initialized || kIsWeb) return;

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
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // repeat daily at same time
    );
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
