import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/network/api_exceptions.dart';
import '../core/services/attendance_salary_mock_store.dart';
import '../core/services/location_service.dart';
import '../core/utils/fetch_cache_mixin.dart';
import '../models/attendance_model.dart';
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

class AttendanceNotifier extends Notifier<AttendanceState> with FetchCacheMixin {
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
    if (!shouldFetch(force: force, hasData: state.dailyOverview != null)) return;

    markFetchStarted();
    state = state.copyWith(isLoading: true, clearError: true);

    final users = ref.read(userManagementProvider);
    final curUser = ref.read(authProvider).currentUser;
    if (curUser != null) {
      AttendanceSalaryMockStore.instance.syncUser(curUser);
    }
    AttendanceSalaryMockStore.instance.syncUsers(users);

    try {
      final repo = ref.read(attendanceRepositoryProvider);
      final overview = await repo.getDailyOverview(targetDate, users);
      markFetchCompleted();
      state = state.copyWith(dailyOverview: overview, isLoading: false, clearError: true);
    } catch (_) {
      markFetchCompleted();
      final fallback = await AttendanceSalaryMockStore.instance.getDailyOverview(targetDate, users);
      state = state.copyWith(dailyOverview: fallback, isLoading: false, clearError: true);
    }
  }

  Future<void> fetchAttendanceRecords({
    String? userId,
    String? date,
    int? month,
    int? year,
    bool force = false,
  }) async {
    final targetUser = userId ?? state.selectedUserId;
    final targetDate = date ?? state.selectedDate;

    if (!shouldFetch(force: force, hasData: state.records.isNotEmpty)) return;

    markFetchStarted();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = ref.read(attendanceRepositoryProvider);
      final records = await repo.getAttendanceRecords(
        userId: targetUser,
        date: date ?? (month == null ? targetDate : null),
        month: month,
        year: year,
      );
      markFetchCompleted();
      state = state.copyWith(records: records, isLoading: false, clearError: true);
    } catch (_) {
      markFetchCompleted();
      final fallback = await AttendanceSalaryMockStore.instance.getAttendanceRecords(
        userId: targetUser,
        date: date ?? (month == null ? targetDate : null),
        month: month,
        year: year,
      );
      state = state.copyWith(records: fallback, isLoading: false, clearError: true);
    }
  }

  /// Triggered automatically on employee login or explicitly via UI button.
  /// Requests geo-location, handles permissions, GPS availability, and network failure.
  Future<bool> checkIn({
    String? explicitSession,
    String? notes,
  }) async {
    // Super Admin & non-attendance roles do not check in
    final currentUser = ref.read(authProvider).currentUser;
    if (currentUser != null && !currentUser.role.requiresAttendanceCheckIn) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: '${currentUser.role.displayName} is exempt from attendance check-in.',
      );
      return false;
    }

    // 0. Enforce session window: morning locks at the divider, afternoon opens at the divider
    final settings = ref.read(attendanceSettingsProvider).value;
    final session = explicitSession ?? resolveSession(settings);
    final windowError = checkInWindowError(session, settings);
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

      final currentUser = ref.read(authProvider).currentUser;
      final userId = currentUser?.id ?? 'a0000000-0000-0000-0000-000000000003';
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
        await AttendanceSalaryMockStore.instance.checkIn(
          userId: userId,
          latitude: lat,
          longitude: lng,
          addressText: address,
          sessionType: explicitSession,
          deviceInfo: deviceInfo,
          notes: resolvedNotes,
          currentUser: currentUser,
        );
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
      await fetchAttendanceRecords(force: true);

      // Refresh notifications from backend so the server-generated attendance notification is loaded
      ref.read(notificationProvider.notifier).fetchNotifications();

      state = state.copyWith(isSubmitting: false, clearError: true);
      return true;
    } catch (_) {
      state = state.copyWith(isSubmitting: false, clearError: true);
      return false;
    }
  }

  static String _fmt(int h) {
    final hh = h % 12 == 0 ? 12 : h % 12;
    return '${hh.toString().padLeft(2, '0')}:00 ${h < 12 ? 'AM' : 'PM'}';
  }

  /// Session for "now" based on the divider (morningEndHour).
  static String resolveSession(AttendanceSettingsState? s) {
    final divider = s?.morningEndHour ?? 13;
    return DateTime.now().hour < divider ? 'morning' : 'afternoon';
  }

  /// Returns null when check-in is allowed; otherwise a reason.
  /// Morning: locks at divider. Afternoon: requires after divider.
  static String? checkInWindowError(String session, AttendanceSettingsState? s) {
    final divider = s?.morningEndHour ?? 13;
    final h = DateTime.now().hour;
    
    if (session == 'morning') {
      if (h >= divider) return 'Morning check-in is locked after ${_fmt(divider)}.';
    } else {
      if (h < divider) return 'Afternoon check-in opens at ${_fmt(divider)}.';
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
    } catch (_) {
      await AttendanceSalaryMockStore.instance.confirmAbsence(userId: userId, date: date, notes: notes);
      invalidateCache();
      await fetchDailyOverview(force: true);
      await fetchAttendanceRecords(force: true);
      state = state.copyWith(isSubmitting: false, clearError: true);
      return true;
    }
  }
}

final attendanceProvider = NotifierProvider<AttendanceNotifier, AttendanceState>(() {
  return AttendanceNotifier();
});
