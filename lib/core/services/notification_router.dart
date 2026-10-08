import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../routing/route_paths.dart';

/// Routes notification taps (local + FCM) to the designated screen.
class NotificationRouter {
  NotificationRouter._();

  static GoRouter? _router;
  static String? _pending;

  /// Whether the logged-in user manages attendance (admin/manager/finance).
  static bool canManageAttendance = false;

  static void attach(GoRouter router) {
    _router = router;
    final p = _pending;
    if (p != null) {
      _pending = null;
      _go(p);
    }
  }

  /// Encode FCM data map into a local-notification payload string.
  static String encode(Map<String, dynamic> data) {
    final params = <String, String>{};
    for (final k in const ['type', 'notificationId', 'expenseId', 'projectId', 'relatedExpenseId', 'relatedProjectId']) {
      final v = data[k];
      if (v != null && v.toString().isNotEmpty) params[k] = v.toString();
    }
    return Uri(queryParameters: params).query;
  }

  static void handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      open(RoutePaths.notifications);
      return;
    }
    Map<String, String> data;
    if (payload.startsWith('expense:')) {
      data = {'expenseId': payload.substring(8)};
    } else {
      try {
        data = Uri.splitQueryString(payload);
      } catch (_) {
        data = {};
      }
    }
    handleData(data);
  }

  static void handleData(Map<String, dynamic> data) => open(resolve(data));

  static String resolve(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString().toLowerCase();
    final expenseId = (data['expenseId'] ?? data['relatedExpenseId'])?.toString();
    final projectId = (data['projectId'] ?? data['relatedProjectId'])?.toString();
    final notifId = data['notificationId']?.toString();

    if (expenseId != null && expenseId.isNotEmpty) return RoutePaths.expenseDetail(expenseId);
    if (type.contains('attendance')) {
      return canManageAttendance ? RoutePaths.attendanceDashboard : RoutePaths.myAttendance;
    }
    if (type.contains('salary') || type.contains('payroll')) {
      return canManageAttendance ? RoutePaths.salaryDashboard : RoutePaths.mySalary;
    }
    if (projectId != null && projectId.isNotEmpty) return RoutePaths.projectDetail(projectId);
    if (notifId != null && notifId.isNotEmpty) return '/notifications/$notifId';
    return RoutePaths.notifications;
  }

  static void open(String location) {
    if (_router == null) {
      _pending = location;
      return;
    }
    _go(location);
  }

  /// Waits until splash/login redirect settles, then pushes the target route.
  static Future<void> _go(String location) async {
    final router = _router!;
    for (var i = 0; i < 40; i++) {
      final path = router.routerDelegate.currentConfiguration.uri.path;
      if (path != RoutePaths.splash && path != RoutePaths.login && path.isNotEmpty) break;
      await Future.delayed(const Duration(milliseconds: 150));
    }
    try {
      router.push(location);
    } catch (e) {
      debugPrint('[NotificationRouter] navigation failed: $e');
    }
  }
}
