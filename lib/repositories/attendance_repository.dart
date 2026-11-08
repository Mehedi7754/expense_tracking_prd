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
    String? date,
    String? status,
    String? addressText,
    String? sessionType,
    String? deviceInfo,
    String? notes,
    String? userId,
    String? workMode,
    String? fieldProjectId,
    String? earlyDepartureReason,
  }) async {
    final localDateStr = date ?? DateFormat('yyyy-MM-dd').format(DateTime.now());

    final finalNotesBuffer = StringBuffer();
    if (workMode == 'field' &&
        !(notes?.toLowerCase().contains('work mode') ?? false)) {
      finalNotesBuffer.write('[Work Mode: Field] ');
    } else if (workMode == 'home' &&
        !(notes?.toLowerCase().contains('work mode') ?? false)) {
      finalNotesBuffer.write('[Work Mode: Home] ');
    } else if (workMode == 'home_office' &&
        !(notes?.toLowerCase().contains('work mode') ?? false)) {
      finalNotesBuffer.write('[Work Mode: Home Office] ');
    }

    if (earlyDepartureReason != null &&
        earlyDepartureReason.isNotEmpty &&
        !(notes?.toLowerCase().contains('early departure') ?? false)) {
      finalNotesBuffer.write('[Early Departure: $earlyDepartureReason] ');
    }

    if (notes != null && notes.trim().isNotEmpty) {
      finalNotesBuffer.write(notes.trim());
    }

    final resolvedNotes = finalNotesBuffer.toString().trim();

    final response = await _client.post(
      ApiEndpoints.attendanceCheckIn,
      body: {
        'latitude': latitude,
        'longitude': longitude,
        'date': localDateStr,
        if (userId != null && userId.isNotEmpty) 'userId': userId,
        if (status != null && status.isNotEmpty) 'status': status,
        if (addressText != null && addressText.isNotEmpty)
          'addressText': addressText,
        if (sessionType != null && sessionType.isNotEmpty)
          'sessionType': sessionType,
        if (deviceInfo != null && deviceInfo.isNotEmpty)
          'deviceInfo': deviceInfo,
        if (resolvedNotes.isNotEmpty) 'notes': resolvedNotes,
        if (workMode != null && workMode.isNotEmpty) 'work_mode': workMode,
        if (workMode == 'field' &&
            fieldProjectId != null &&
            fieldProjectId.isNotEmpty)
          'field_project_id': fieldProjectId,
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
    if (sessionType != null && sessionType.isNotEmpty)
      queryParams['sessionType'] = sessionType;

    String url = ApiEndpoints.attendance;
    if (queryParams.isNotEmpty) {
      final queryString = Uri(queryParameters: queryParams).query;
      url = '$url?$queryString';
    }

    final response = await _client.get(url);
    if (response is List) {
      return response
          .map(
            (item) =>
                AttendanceRecordModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    }
    return const [];
  }

  Future<DailyAttendanceOverview> getDailyOverview([
    String? date,
    List<UserModel>? explicitUsers,
  ]) async {
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
    final url =
        '${ApiEndpoints.attendanceSummary}?userId=$userId&month=$month&year=$year';
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
    int? breakStartHour,
    int? breakEndHour,
    List<int>? weekendDays,
    String? deductionType,
    double? fullDayDeductionAmount,
    double? halfDayDeductionAmount,
    List<Map<String, dynamic>>? shifts,
    Map<String, String>? userShifts,
    double? officeLatitude,
    double? officeLongitude,
    String? officeName,
    String? officeAddress,
    double? geofenceRadiusMeters,
    bool? isGeofenceEnforced,
  }) async {
    final body = <String, dynamic>{
      if (morningStartHour != null) 'morningStartHour': morningStartHour,
      'morningEndHour': morningEndHour,
      'afternoonStartHour': afternoonStartHour ?? morningEndHour,
      if (afternoonEndHour != null) 'afternoonEndHour': afternoonEndHour,
      'breakStartHour': breakStartHour ?? morningEndHour,
      'breakEndHour': breakEndHour ?? (afternoonStartHour ?? morningEndHour),
      if (weekendDays != null) 'weekendDays': weekendDays,
      if (deductionType != null) 'deductionType': deductionType,
      if (fullDayDeductionAmount != null)
        'fullDayDeductionAmount': fullDayDeductionAmount,
      if (halfDayDeductionAmount != null)
        'halfDayDeductionAmount': halfDayDeductionAmount,
      if (shifts != null) 'shifts': shifts,
      if (userShifts != null) 'userShifts': userShifts,
      if (officeLatitude != null) 'officeLatitude': officeLatitude,
      if (officeLongitude != null) 'officeLongitude': officeLongitude,
      if (officeName != null) 'officeName': officeName,
      if (officeAddress != null) 'officeAddress': officeAddress,
      if (geofenceRadiusMeters != null)
        'geofenceRadiusMeters': geofenceRadiusMeters,
      if (isGeofenceEnforced != null) 'isGeofenceEnforced': isGeofenceEnforced,
    };
    final response = await _client.post('/attendance/settings', body: body);
    return response != null;
  }

  Future<Map<String, dynamic>?> overrideAttendance({
    required List<String> userIds,
    required String startDate,
    required String endDate,
    String? status,
    String? workMode,
    bool? skipWeekends,
    bool? skipHolidays,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'userIds': userIds,
      'startDate': startDate,
      'endDate': endDate,
      if (status != null) 'status': status,
      if (workMode != null) 'workMode': workMode,
      if (skipWeekends != null) 'skipWeekends': skipWeekends,
      if (skipHolidays != null) 'skipHolidays': skipHolidays,
      if (notes != null) 'notes': notes,
    };
    final response = await _client.post(ApiEndpoints.attendanceOverride, body: body);
    if (response is Map<String, dynamic>) {
      return response;
    }
    return null;
  }

  Future<Map<String, dynamic>?> assignWorkLocations({
    required List<String> userIds,
    required String startDate,
    required String endDate,
    required String workLocation,
    String? projectId,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'userIds': userIds,
      'startDate': startDate,
      'endDate': endDate,
      'workLocation': workLocation,
      if (projectId != null && projectId.isNotEmpty) 'projectId': projectId,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
    final response = await _client.post(ApiEndpoints.attendanceWorkLocationsAssign, body: body);
    if (response is Map<String, dynamic>) {
      return response;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getWorkLocationAssignments({
    String? startDate,
    String? endDate,
    String? userId,
  }) async {
    final params = <String>[];
    if (startDate != null && startDate.isNotEmpty) params.add('startDate=$startDate');
    if (endDate != null && endDate.isNotEmpty) params.add('endDate=$endDate');
    if (userId != null && userId.isNotEmpty) params.add('userId=$userId');
    final qs = params.isNotEmpty ? '?${params.join('&')}' : '';
    final response = await _client.get('${ApiEndpoints.attendanceWorkLocations}$qs');
    if (response is List) {
      return response.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }
    return [];
  }
}

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(ref.watch(apiClientProvider));
});
