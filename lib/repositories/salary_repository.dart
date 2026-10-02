import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/services/attendance_salary_mock_store.dart';
import '../models/holiday_model.dart';
import '../models/leave_model.dart';
import '../models/salary_model.dart';
import '../models/user_model.dart';

class SalaryRepository {
  final ApiClient _client;

  SalaryRepository(this._client);

  Future<EmployeeSalaryProfile> getEmployeeSalary(String userId) async {
    try {
      final response = await _client.get(ApiEndpoints.employeeSalary(userId));
      if (response is Map<String, dynamic>) {
        return EmployeeSalaryProfile.fromJson(response);
      }
    } catch (e) {
      debugPrint('[SalaryRepository] API getEmployeeSalary failed ($e), using local fallback store');
    }

    return await AttendanceSalaryMockStore.instance.getEmployeeSalary(userId);
  }

  Future<EmployeeSalaryProfile> setEmployeeSalary(
    String userId,
    double monthlySalary, {
    int standardWorkingDays = 22,
    String currency = 'BDT',
  }) async {
    try {
      final response = await _client.post(
        ApiEndpoints.employeeSalary(userId),
        body: {
          'monthlySalary': monthlySalary,
          'standardWorkingDays': standardWorkingDays,
          'currency': currency,
        },
      );
      if (response is Map<String, dynamic>) {
        final profile = EmployeeSalaryProfile.fromJson(response);
        await AttendanceSalaryMockStore.instance.setEmployeeSalary(
          userId,
          monthlySalary,
          standardWorkingDays: standardWorkingDays,
          currency: currency,
        );
        return profile;
      }
    } catch (e) {
      debugPrint('[SalaryRepository] API setEmployeeSalary failed ($e), saving to local store');
    }

    return await AttendanceSalaryMockStore.instance.setEmployeeSalary(
      userId,
      monthlySalary,
      standardWorkingDays: standardWorkingDays,
      currency: currency,
    );
  }

  Future<SalaryCalculationModel> calculateSalary(String userId, int month, int year) async {
    final url = '${ApiEndpoints.calculateSalary(userId)}?month=$month&year=$year';
    try {
      final response = await _client.get(url);
      if (response is Map<String, dynamic>) {
        return SalaryCalculationModel.fromJson(response);
      }
    } catch (e) {
      debugPrint('[SalaryRepository] API calculateSalary failed ($e), calculating via local store');
    }

    return await AttendanceSalaryMockStore.instance.calculateSalary(userId, month, year);
  }

  Future<bool> saveCalculation(String userId, int month, int year, {String? notes}) async {
    try {
      final response = await _client.post(
        ApiEndpoints.saveSalaryCalculation,
        body: {
          'userId': userId,
          'month': month,
          'year': year,
          if (notes != null) 'notes': notes,
        },
      );
      if (response is Map<String, dynamic>) {
        return response['success'] == true;
      }
    } catch (e) {
      debugPrint('[SalaryRepository] API saveCalculation failed ($e), saved locally');
    }
    return true;
  }

  Future<OrgSalaryReportModel> getOrgSalaryReport(int month, int year, [List<UserModel>? explicitUsers]) async {
    final url = '${ApiEndpoints.salaryReport}?month=$month&year=$year';
    try {
      final response = await _client.get(url);
      if (response is Map<String, dynamic>) {
        final report = OrgSalaryReportModel.fromJson(response);
        if (report.employees.isNotEmpty) {
          return report;
        }
      }
    } catch (e) {
      debugPrint('[SalaryRepository] API getOrgSalaryReport failed ($e), using local fallback store');
    }

    return await AttendanceSalaryMockStore.instance.getOrgSalaryReport(month, year, explicitUsers);
  }

  // --- Holidays ---
  Future<List<HolidayModel>> getHolidays([int? year]) async {
    String url = ApiEndpoints.holidays;
    if (year != null) url = '$url?year=$year';
    try {
      final response = await _client.get(url);
      if (response is List && response.isNotEmpty) {
        return response.map((e) => HolidayModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[SalaryRepository] API getHolidays failed ($e), using local fallback store');
    }

    return await AttendanceSalaryMockStore.instance.getHolidays(year);
  }

  Future<HolidayModel> addHoliday({
    required String date,
    required String name,
    bool isRecurring = false,
  }) async {
    try {
      final response = await _client.post(
        ApiEndpoints.holidays,
        body: {
          'date': date,
          'name': name,
          'isRecurring': isRecurring,
        },
      );
      if (response is Map<String, dynamic>) {
        return HolidayModel.fromJson(response);
      }
    } catch (e) {
      debugPrint('[SalaryRepository] API addHoliday failed: $e');
    }

    return HolidayModel(
      id: 'hol-${DateTime.now().millisecondsSinceEpoch}',
      date: date,
      name: name,
      isRecurring: isRecurring,
    );
  }

  Future<bool> deleteHoliday(String id) async {
    try {
      final response = await _client.delete(ApiEndpoints.holidayById(id));
      if (response is Map<String, dynamic>) {
        return response['success'] == true;
      }
    } catch (e) {
      debugPrint('[SalaryRepository] API deleteHoliday failed: $e');
    }
    return true;
  }

  // --- Leaves ---
  Future<List<LeaveRecordModel>> getLeaves({String? userId, int? month, int? year}) async {
    final queryParams = <String, String>{};
    if (userId != null && userId.isNotEmpty) queryParams['userId'] = userId;
    if (month != null) queryParams['month'] = month.toString();
    if (year != null) queryParams['year'] = year.toString();

    String url = ApiEndpoints.leaves;
    if (queryParams.isNotEmpty) {
      final qs = Uri(queryParameters: queryParams).query;
      url = '$url?$qs';
    }

    try {
      final response = await _client.get(url);
      if (response is List) {
        return response.map((e) => LeaveRecordModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[SalaryRepository] API getLeaves failed: $e');
    }
    return [];
  }

  Future<LeaveRecordModel> addLeave({
    required String userId,
    required String startDate,
    required String endDate,
    required String leaveType,
    String? reason,
    bool isApproved = true,
  }) async {
    try {
      final response = await _client.post(
        ApiEndpoints.leaves,
        body: {
          'userId': userId,
          'startDate': startDate,
          'endDate': endDate,
          'leaveType': leaveType,
          if (reason != null) 'reason': reason,
          'isApproved': isApproved,
        },
      );
      if (response is Map<String, dynamic>) {
        return LeaveRecordModel.fromJson(response);
      }
    } catch (e) {
      debugPrint('[SalaryRepository] API addLeave failed: $e');
    }

    return LeaveRecordModel(
      id: 'leave-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      userName: 'Employee',
      startDate: startDate,
      endDate: endDate,
      leaveType: leaveType,
      reason: reason ?? '',
      isApproved: isApproved,
    );
  }

  Future<bool> deleteLeave(String id) async {
    try {
      final response = await _client.delete(ApiEndpoints.leaveById(id));
      if (response is Map<String, dynamic>) {
        return response['success'] == true;
      }
    } catch (e) {
      debugPrint('[SalaryRepository] API deleteLeave failed: $e');
    }
    return true;
  }

  // --- Adjustments ---
  Future<List<SalaryAdjustmentModel>> getAdjustments(String userId, {int? month, int? year}) async {
    String url = ApiEndpoints.salaryAdjustments(userId);
    final qp = <String, String>{};
    if (month != null) qp['month'] = month.toString();
    if (year != null) qp['year'] = year.toString();
    if (qp.isNotEmpty) {
      url = '$url?${Uri(queryParameters: qp).query}';
    }

    try {
      final response = await _client.get(url);
      if (response is List) {
        return response.map((e) => SalaryAdjustmentModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[SalaryRepository] API getAdjustments failed: $e');
    }
    return [];
  }

  Future<SalaryAdjustmentModel> addAdjustment({
    required String userId,
    required String adjustmentType,
    required double amount,
    required String reason,
    int? month,
    int? year,
  }) async {
    try {
      final response = await _client.post(
        ApiEndpoints.addSalaryAdjustment,
        body: {
          'userId': userId,
          'adjustmentType': adjustmentType,
          'amount': amount,
          'reason': reason,
          if (month != null) 'month': month,
          if (year != null) 'year': year,
        },
      );
      if (response is Map<String, dynamic>) {
        return SalaryAdjustmentModel.fromJson(response);
      }
    } catch (e) {
      debugPrint('[SalaryRepository] API addAdjustment failed: $e');
    }

    return SalaryAdjustmentModel(
      id: 'adj-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      adjustmentType: adjustmentType,
      amount: amount,
      reason: reason,
      createdAt: DateTime.now(),
    );
  }
}

final salaryRepositoryProvider = Provider<SalaryRepository>((ref) {
  return SalaryRepository(ref.watch(apiClientProvider));
});
