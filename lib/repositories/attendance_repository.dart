import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/api_exceptions.dart';
import '../core/services/attendance_salary_mock_store.dart';
import '../models/attendance_model.dart';
import '../models/user_model.dart';

class AttendanceRepository {
  final ApiClient _client;

  AttendanceRepository(this._client);

  Future<AttendanceRecordModel> checkIn({
    required double latitude,
    required double longitude,
    String? addressText,
    String? sessionType,
    String? deviceInfo,
    String? notes,
    String? userId,
  }) async {
    try {
      final response = await _client.post(
        ApiEndpoints.attendanceCheckIn,
        body: {
          'latitude': latitude,
          'longitude': longitude,
          if (addressText != null && addressText.isNotEmpty) 'addressText': addressText,
          if (sessionType != null && sessionType.isNotEmpty) 'sessionType': sessionType,
          if (deviceInfo != null && deviceInfo.isNotEmpty) 'deviceInfo': deviceInfo,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );

      if (response is Map<String, dynamic>) {
        final record = AttendanceRecordModel.fromJson(response);
        // Sync to mock store for offline continuity
        await AttendanceSalaryMockStore.instance.checkIn(
          userId: record.userId,
          latitude: latitude,
          longitude: longitude,
          addressText: addressText,
          sessionType: sessionType,
          deviceInfo: deviceInfo,
          notes: notes,
        );
        return record;
      }
    } on ApiException catch (e) {
      final code = e.statusCode ?? 0;
      if (code >= 400 && code < 500) rethrow; // server rejected (e.g. window closed) — never fake it locally
    } catch (_) {}

    // Local fallback store
    return await AttendanceSalaryMockStore.instance.checkIn(
      userId: userId ?? 'a0000000-0000-0000-0000-000000000003',
      latitude: latitude,
      longitude: longitude,
      addressText: addressText,
      sessionType: sessionType,
      deviceInfo: deviceInfo,
      notes: notes,
    );
  }

  Future<List<AttendanceRecordModel>> getAttendanceRecords({
    String? userId,
    String? date,
    int? month,
    int? year,
    String? sessionType,
  }) async {
    final queryParams = <String, String>{};
    if (userId != null && userId.isNotEmpty) queryParams['userId'] = userId;
    if (date != null && date.isNotEmpty) queryParams['date'] = date;
    if (month != null) queryParams['month'] = month.toString();
    if (year != null) queryParams['year'] = year.toString();
    if (sessionType != null && sessionType.isNotEmpty) queryParams['sessionType'] = sessionType;

    String url = ApiEndpoints.attendance;
    if (queryParams.isNotEmpty) {
      final queryString = Uri(queryParameters: queryParams).query;
      url = '$url?$queryString';
    }

    try {
      final response = await _client.get(url);
      if (response is List && response.isNotEmpty) {
        return response
            .map((item) => AttendanceRecordModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    return await AttendanceSalaryMockStore.instance.getAttendanceRecords(
      userId: userId,
      date: date,
      month: month,
      year: year,
      sessionType: sessionType,
    );
  }

  Future<DailyAttendanceOverview> getDailyOverview([String? date, List<UserModel>? explicitUsers]) async {
    String url = ApiEndpoints.attendanceOverview;
    if (date != null && date.isNotEmpty) {
      url = '$url?date=$date';
    }

    try {
      final response = await _client.get(url);
      if (response is Map<String, dynamic>) {
        final overview = DailyAttendanceOverview.fromJson(response);
        if (overview.employees.isNotEmpty) {
          return overview;
        }
      }
    } catch (_) {}

    return await AttendanceSalaryMockStore.instance.getDailyOverview(date, explicitUsers);
  }

  Future<AttendanceSummaryModel> getAttendanceSummary({
    required String userId,
    required int month,
    required int year,
  }) async {
    final url = '${ApiEndpoints.attendanceSummary}?userId=$userId&month=$month&year=$year';
    try {
      final response = await _client.get(url);
      if (response is Map<String, dynamic>) {
        return AttendanceSummaryModel.fromJson(response);
      }
    } catch (_) {}

    final calc = await AttendanceSalaryMockStore.instance.calculateSalary(userId, month, year);
    final records = await AttendanceSalaryMockStore.instance.getAttendanceRecords(userId: userId, month: month, year: year);
    return AttendanceSummaryModel(
      userId: userId,
      month: month,
      year: year,
      totalRecords: records.length,
      fullPresentDays: calc.presentDays,
      halfDays: calc.halfDays,
      totalPresentEquivalent: calc.totalPresentEquivalent,
    );
  }

  Future<bool> confirmAbsence({
    required String userId,
    required String date,
    String? notes,
  }) async {
    try {
      final response = await _client.post(
        ApiEndpoints.confirmAbsence,
        body: {
          'userId': userId,
          'date': date,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      if (response is Map<String, dynamic> && response['success'] == true) {
        await AttendanceSalaryMockStore.instance.confirmAbsence(userId: userId, date: date, notes: notes);
        return true;
      }
    } catch (_) {}

    return await AttendanceSalaryMockStore.instance.confirmAbsence(
      userId: userId,
      date: date,
      notes: notes,
    );
  }

  Future<Map<String, dynamic>?> getAttendanceSettings() async {
    try {
      final response = await _client.get('/attendance/settings');
      if (response is Map<String, dynamic>) {
        return response;
      }
    } catch (_) {}
    return null;
  }

  Future<bool> updateAttendanceSettings({
    int? morningStartHour,
    required int morningEndHour,
    int? afternoonEndHour,
    List<int>? weekendDays,
    String? deductionType,
    double? fullDayDeductionAmount,
    double? halfDayDeductionAmount,
    List<Map<String, dynamic>>? shifts,
    Map<String, String>? userShifts,
  }) async {
    try {
      final body = <String, dynamic>{
        if (morningStartHour != null) 'morningStartHour': morningStartHour,
        'morningEndHour': morningEndHour,
        if (afternoonEndHour != null) 'afternoonEndHour': afternoonEndHour,
        if (weekendDays != null) 'weekendDays': weekendDays,
        if (deductionType != null) 'deductionType': deductionType,
        if (fullDayDeductionAmount != null) 'fullDayDeductionAmount': fullDayDeductionAmount,
        if (halfDayDeductionAmount != null) 'halfDayDeductionAmount': halfDayDeductionAmount,
        if (shifts != null) 'shifts': shifts,
        if (userShifts != null) 'userShifts': userShifts,
      };
      final response = await _client.post(
        '/attendance/settings',
        body: body,
      );
      return response != null;
    } catch (_) {
      return false;
    }
  }
}

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(ref.watch(apiClientProvider));
});
