import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/network/api_exceptions.dart';
import '../core/services/location_service.dart';
import '../core/services/push_notification_service.dart';
import '../models/attendance_model.dart';
import '../models/user_role.dart';
import '../repositories/attendance_repository.dart';
import 'attendance_settings_provider.dart';
import 'auth_provider.dart';
import 'notification_provider.dart';
import 'user_management_provider.dart';

class AttendanceState {
  final List<AttendanceRecordModel> records;
  final DailyAttendanceOverview? dailyOverview;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;
  final String selectedDate;
  final String? selectedUserId;

  const AttendanceState({
    this.records = const [],
    this.dailyOverview,
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
    required this.selectedDate,
    this.selectedUserId,
  });

  AttendanceState copyWith({
    List<AttendanceRecordModel>? records,
    DailyAttendanceOverview? dailyOverview,
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    String? selectedDate,
    String? selectedUserId,
    bool clearSelectedUser = false,
  }) {
    return AttendanceState(
      records: records ?? this.records,
      dailyOverview: dailyOverview ?? this.dailyOverview,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      selectedDate: selectedDate ?? this.selectedDate,
      selectedUserId: clearSelectedUser ? null : (selectedUserId ?? this.selectedUserId),
    );
  }
}

class AttendanceNotifier extends Notifier<AttendanceState> {
  DateTime? _lastOverviewFetchTime;
  bool _isFetchingOverview = false;

  DateTime? _lastRecordsFetchTime;
  bool _isFetchingRecords = false;
  String? _lastRecordsUserId;
  String? _lastRecordsDate;

  void invalidateCache() {
    _lastOverviewFetchTime = null;
    _lastRecordsFetchTime = null;
    _lastRecordsUserId = null;
    _lastRecordsDate = null;
  }

  @override
  AttendanceState build() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return AttendanceState(selectedDate: today);
  }

  void setSelectedDate(String date) {
    state = state.copyWith(selectedDate: date);
    fetchDailyOverview(date: date, force: true);
    fetchAttendanceRecords(date: date, force: true);
  }

  void setSelectedUser(String? userId) {
    if (userId == null) {
      state = state.copyWith(clearSelectedUser: true);
    } else {
      state = state.copyWith(selectedUserId: userId);
    }
    fetchAttendanceRecords(userId: userId, force: true);
  }

  Future<void> fetchDailyOverview({String? date, bool force = false}) async {
    final targetDate = date ?? state.selectedDate;
    if (_isFetchingOverview) return;
    if (!force &&
        _lastOverviewFetchTime != null &&
        DateTime.now().difference(_lastOverviewFetchTime!) < const Duration(minutes: 2) &&
        state.dailyOverview != null) {
      return;
    }

    _isFetchingOverview = true;
    state = state.copyWith(isLoading: true, clearError: true);

    var users = ref.read(userManagementProvider);
    if (users.isEmpty) {
      try {
        await ref.read(userManagementProvider.notifier).fetchUsers();
        users = ref.read(userManagementProvider);
      } catch (_) {}
    }

    try {
      final repo = ref.read(attendanceRepositoryProvider);
      final overview = await repo.getDailyOverview(targetDate, users);
      _lastOverviewFetchTime = DateTime.now();
      state = state.copyWith(dailyOverview: overview, isLoading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    } finally {
      _isFetchingOverview = false;
    }
  }

  Future<void> fetchAttendanceRecords({
    String? userId,
    String? date,
    int? month,
    int? year,
    bool force = false,
  }) async {
    final authUser = ref.read(authProvider).currentUser;
    final isEmployee = authUser?.role == UserRole.projectMember;
    final effectiveUserId = userId ?? (isEmployee ? authUser?.id : state.selectedUserId);

    // If fetching for a specific user and date is not explicitly specified,
    // do not force today's date so that historical records are retrieved.
    final String? resolvedDate = date ?? (effectiveUserId != null ? null : (month == null ? state.selectedDate : null));

    final isParamsChanged = effectiveUserId != _lastRecordsUserId || resolvedDate != _lastRecordsDate;

    if (_isFetchingRecords) return;
    if (!force &&
        !isParamsChanged &&
        _lastRecordsFetchTime != null &&
        DateTime.now().difference(_lastRecordsFetchTime!) < const Duration(minutes: 1) &&
        state.records.isNotEmpty) {
      return;
    }

    _isFetchingRecords = true;
    _lastRecordsUserId = effectiveUserId;
    _lastRecordsDate = resolvedDate;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = ref.read(attendanceRepositoryProvider);
      final records = await repo.getAttendanceRecords(
        userId: effectiveUserId,
        date: resolvedDate,
        month: month,
        year: year,
      );
      _lastRecordsFetchTime = DateTime.now();
      state = state.copyWith(
        records: records,
        selectedUserId: effectiveUserId ?? state.selectedUserId,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    } finally {
      _isFetchingRecords = false;
    }
  }

  /// Triggered automatically on employee login or explicitly via UI button.
  /// Requests geo-location, handles permissions, GPS availability, and network failure.
  Future<bool> checkIn({
    String? explicitSession,
    String? notes,
  }) async {
    final currentUser = ref.read(authProvider).currentUser;
    if (currentUser == null || currentUser.id.isEmpty) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'User session not found. Please log in.',
      );
      return false;
    }
    // Super Admin & non-attendance roles do not check in
    if (!currentUser.role.requiresAttendanceCheckIn) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: '${currentUser.role.displayName} is exempt from attendance check-in.',
      );
      return false;
    }

    final userId = currentUser.id;

    // 0. Enforce session window: morning locks at the divider, afternoon opens at the divider
    final settings = ref.read(attendanceSettingsProvider).value;
    final session = explicitSession ?? resolveSession(settings, userId: userId);
    final windowError = checkInWindowError(session, settings, userId: userId);
    if (windowError != null) {
      state = state.copyWith(isSubmitting: false, errorMessage: windowError);
      return false;
    }
    explicitSession = session;

    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      // 1. Get GPS coordinates with permission checking and timeout
      final locResult = await LocationService.getCurrentCoordinates();

      if (!locResult.isSuccess || locResult.latitude == null || locResult.longitude == null) {
        final errMsg = locResult.errorMessage ?? 'Unable to acquire verified GPS coordinates. Please enable device location.';
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: errMsg,
        );
        return false;
      }

      final lat = locResult.latitude!;
      final lng = locResult.longitude!;
      final address = locResult.addressText;
      final resolvedNotes = notes ?? '';

      final deviceInfo = kIsWeb ? 'Web Browser' : (Platform.isAndroid ? 'Android' : (Platform.isIOS ? 'iOS' : 'Desktop'));

      final repo = ref.read(attendanceRepositoryProvider);

      try {
        await repo.checkIn(
          latitude: lat,
          longitude: lng,
          addressText: address,
          sessionType: explicitSession,
          deviceInfo: deviceInfo,
          notes: resolvedNotes,
          userId: userId,
        );
      } on ApiException catch (apiErr) {
        final code = apiErr.statusCode ?? 0;
        if (code >= 400 && code < 500) {
          state = state.copyWith(isSubmitting: false, errorMessage: apiErr.message);
          return false;
        }
        rethrow;
      } catch (_) {
        await LocationService.queueOfflineCheckIn(
          userId: userId,
          latitude: lat,
          longitude: lng,
          sessionType: explicitSession,
          addressText: address,
        );
      }

      invalidateCache();
      await fetchDailyOverview(force: true);
      await fetchAttendanceRecords(userId: userId, force: true);

      // Fire OS status bar push notification immediately
      PushNotificationService.instance.showAttendanceReminder(
        title: 'Attendance Recorded 📍',
        body: 'Your check-in for the $explicitSession session was recorded successfully.',
        notificationId: 'checkin_${DateTime.now().millisecondsSinceEpoch}',
      );

      // Refresh notifications from backend so the server-generated attendance notification is loaded
      ref.read(notificationProvider.notifier).fetchNotifications();

      state = state.copyWith(isSubmitting: false, clearError: true);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }

  static String _fmt(int h) {
    final hh = h % 12 == 0 ? 12 : h % 12;
    return '${hh.toString().padLeft(2, '0')}:00 ${h < 12 ? 'AM' : 'PM'}';
  }

  /// Session for "now" based on the divider or employee's shift.
  static String resolveSession(AttendanceSettingsState? s, {String? userId}) {
    if (s != null && userId != null) {
      final shift = s.getShiftForUser(userId);
      return DateTime.now().hour < shift.morningEndHour ? 'morning' : 'afternoon';
    }
    final divider = s?.morningEndHour ?? 13;
    return DateTime.now().hour < divider ? 'morning' : 'afternoon';
  }

  /// Returns null when check-in is allowed; otherwise a reason.
  /// Evaluates specific shift timings. Afternoon check-out is permitted anytime.
  static String? checkInWindowError(String session, AttendanceSettingsState? s, {String? userId}) {
    // Afternoon session is check-out / departure; employees can check out at any time.
    if (session == 'afternoon') {
      return null;
    }

    if (s != null && userId != null) {
      final shift = s.getShiftForUser(userId);
      final h = DateTime.now().hour;

      if (session == 'morning') {
        if (h < shift.morningStartHour) return 'Morning check-in for ${shift.name} opens at ${_fmt(shift.morningStartHour)}.';
        if (h >= shift.morningEndHour) return 'Morning check-in for ${shift.name} is locked after ${_fmt(shift.morningEndHour)}.';
      }
      return null;
    }

    final divider = s?.morningEndHour ?? 13;
    final h = DateTime.now().hour;
    
    if (session == 'morning') {
      if (h >= divider) return 'Morning check-in is locked after ${_fmt(divider)}.';
    }
    return null;
  }

  /// Syncs any pending offline check-ins saved locally
  Future<void> syncOfflineCheckIns() async {
    try {
      final queue = await LocationService.getOfflineCheckIns();
      if (queue.isEmpty) return;

      final repo = ref.read(attendanceRepositoryProvider);
      final remaining = <Map<String, dynamic>>[];

      for (final item in queue) {
        try {
          await repo.checkIn(
            latitude: (item['latitude'] as num).toDouble(),
            longitude: (item['longitude'] as num).toDouble(),
            addressText: item['addressText'] as String?,
            sessionType: item['sessionType'] as String?,
            deviceInfo: 'Offline Sync Queue',
            userId: item['userId'] as String?,
          );
        } catch (_) {
          remaining.add(item);
        }
      }

      if (remaining.length != queue.length) {
        await LocationService.clearOfflineCheckIns();
        for (final rem in remaining) {
          await LocationService.queueOfflineCheckIn(
            userId: rem['userId'] ?? '',
            latitude: (rem['latitude'] as num).toDouble(),
            longitude: (rem['longitude'] as num).toDouble(),
            sessionType: rem['sessionType'] ?? 'morning',
            addressText: rem['addressText'] ?? '',
          );
        }
        invalidateCache();
        await fetchDailyOverview(force: true);
      }
    } catch (_) {}
  }

  Future<bool> confirmAbsence({
    required String userId,
    required String date,
    String? notes,
  }) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final repo = ref.read(attendanceRepositoryProvider);
      final success = await repo.confirmAbsence(userId: userId, date: date, notes: notes);
      if (success) {
        invalidateCache();
        await fetchDailyOverview(force: true);
        await fetchAttendanceRecords(force: true);
      }
      state = state.copyWith(isSubmitting: false, clearError: true);
      return success;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }
}

final attendanceProvider = NotifierProvider<AttendanceNotifier, AttendanceState>(() {
  return AttendanceNotifier();
});
