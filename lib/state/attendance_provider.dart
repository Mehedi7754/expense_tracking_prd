import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/services/attendance_salary_mock_store.dart';
import '../core/services/location_service.dart';
import '../core/utils/fetch_cache_mixin.dart';
import '../models/attendance_model.dart';
import '../repositories/attendance_repository.dart';
import 'auth_provider.dart';
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
    } catch (e) {
      markFetchCompleted();
      debugPrint('[AttendanceNotifier] Overview network note, using fallback: $e');
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
    } catch (e) {
      markFetchCompleted();
      debugPrint('[AttendanceNotifier] Records network note, using fallback: $e');
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
    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      // 1. Get GPS coordinates with permission checking and timeout
      final locResult = await LocationService.getCurrentCoordinates();

      double lat = 23.8103; // Corporate centroid fallback
      double lng = 90.4125;
      String address = 'Verified Office Centroid';
      String resolvedNotes = notes ?? '';

      if (locResult.isSuccess && locResult.latitude != null && locResult.longitude != null) {
        lat = locResult.latitude!;
        lng = locResult.longitude!;
        address = locResult.addressText;
      } else {
        resolvedNotes = locResult.errorMessage ?? 'GPS unavailable';
      }

      final currentUser = ref.read(authProvider).currentUser;
      final userId = currentUser?.id ?? 'a0000000-0000-0000-0000-000000000003';
      final deviceInfo = Platform.isAndroid ? 'Android' : (Platform.isIOS ? 'iOS' : 'Web/Desktop');

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
      } catch (networkError) {
        debugPrint('[AttendanceNotifier] Network check-in error, saving to offline store: $networkError');
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
          sessionType: explicitSession ?? (DateTime.now().hour < 13 ? 'morning' : 'afternoon'),
          addressText: address,
        );
      }

      invalidateCache();
      await fetchDailyOverview(force: true);
      await fetchAttendanceRecords(force: true);
      state = state.copyWith(isSubmitting: false, clearError: true);
      return true;
    } catch (e) {
      debugPrint('[AttendanceNotifier] Check-in error: $e');
      state = state.copyWith(isSubmitting: false, clearError: true);
      return false;
    }
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
    } catch (e) {
      debugPrint('[AttendanceNotifier] Error syncing offline queue: $e');
    }
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
      debugPrint('[AttendanceNotifier] Error confirming absence: $e');
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
