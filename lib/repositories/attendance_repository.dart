import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
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
    final localDateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final response = await _client.post(
      ApiEndpoints.attendanceCheckIn,
      body: {
        'latitude': latitude,
        'longitude': longitude,
        'date': localDateStr,
        if (addressText != null && addressText.isNotEmpty) 'addressText': addressText,
        if (sessionType != null && sessionType.isNotEmpty) 'sessionType': sessionType,
        if (deviceInfo != null && deviceInfo.isNotEmpty) 'deviceInfo': deviceInfo,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );

    if (response is Map<String, dynamic>) {
      return AttendanceRecordModel.fromJson(response);
    }
    throw const FormatException('Invalid server response for check-in');
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

    final response = await _client.get(url);
    if (response is List) {
      return response
          .map((item) => AttendanceRecordModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return const [];
  }

  Future<DailyAttendanceOverview> getDailyOverview([String? date, List<UserModel>? explicitUsers]) async {
    String url = ApiEndpoints.attendanceOverview;
    if (date != null && date.isNotEmpty) {
      url = '$url?date=$date';
    }

    final response = await _client.get(url);
    if (response is Map<String, dynamic>) {
      return DailyAttendanceOverview.fromJson(response);
    }
    return DailyAttendanceOverview(
      date: date ?? '',
      totalEmployees: 0,
      presentCount: 0,
      halfDayCount: 0,
      missingCount: 0,
      employees: const [],
    );
  }

  Future<AttendanceSummaryModel> getAttendanceSummary({
    required String userId,
    required int month,
    required int year,
  }) async {
    final url = '${ApiEndpoints.attendanceSummary}?userId=$userId&month=$month&year=$year';
    final response = await _client.get(url);
    if (response is Map<String, dynamic>) {
      return AttendanceSummaryModel.fromJson(response);
    }
    return AttendanceSummaryModel(
      userId: userId,
      month: month,
      year: year,
      totalRecords: 0,
      fullPresentDays: 0,
      halfDays: 0,
      totalPresentEquivalent: 0,
    );
  }

  Future<bool> confirmAbsence({
    required String userId,
    required String date,
    String? notes,
  }) async {
    final response = await _client.post(
      ApiEndpoints.confirmAbsence,
      body: {
        'userId': userId,
        'date': date,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    if (response is Map<String, dynamic>) {
      return response['success'] == true;
    }
    return false;
  }

  Future<Map<String, dynamic>?> getAttendanceSettings() async {
    final response = await _client.get('/attendance/settings');
    if (response is Map<String, dynamic>) {
      return response;
    }
    return null;
  }

  Future<bool> updateAttendanceSettings({
    int? morningStartHour,
    required int morningEndHour,
    int? afternoonStartHour,
    int? afternoonEndHour,
    List<int>? weekendDays,
    String? deductionType,
    double? fullDayDeductionAmount,
    double? halfDayDeductionAmount,
    List<Map<String, dynamic>>? shifts,
    Map<String, String>? userShifts,
  }) async {
    final body = <String, dynamic>{
      if (morningStartHour != null) 'morningStartHour': morningStartHour,
      'morningEndHour': morningEndHour,
      'afternoonStartHour': afternoonStartHour ?? morningEndHour,
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
  }
}

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(ref.watch(apiClientProvider));
});
