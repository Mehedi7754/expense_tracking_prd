import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/fetch_cache_mixin.dart';
import '../models/holiday_model.dart';
import '../models/leave_model.dart';
import '../models/salary_model.dart';
import '../repositories/salary_repository.dart';
import '../core/services/attendance_salary_mock_store.dart';
import 'auth_provider.dart';
import 'user_management_provider.dart';

class SalaryState {
  final OrgSalaryReportModel? orgReport;
  final SalaryCalculationModel? currentCalculation;
  final EmployeeSalaryProfile? currentEmployeeSalary;
  final List<HolidayModel> holidays;
  final List<LeaveRecordModel> leaves;
  final int selectedMonth;
  final int selectedYear;
  final String? selectedUserId;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;

  const SalaryState({
    this.orgReport,
    this.currentCalculation,
    this.currentEmployeeSalary,
    this.holidays = const [],
    this.leaves = const [],
    required this.selectedMonth,
    required this.selectedYear,
    this.selectedUserId,
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
  });

  SalaryState copyWith({
    OrgSalaryReportModel? orgReport,
    SalaryCalculationModel? currentCalculation,
    EmployeeSalaryProfile? currentEmployeeSalary,
    List<HolidayModel>? holidays,
    List<LeaveRecordModel>? leaves,
    int? selectedMonth,
    int? selectedYear,
    String? selectedUserId,
    bool clearSelectedUser = false,
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SalaryState(
      orgReport: orgReport ?? this.orgReport,
      currentCalculation: currentCalculation ?? this.currentCalculation,
      currentEmployeeSalary: currentEmployeeSalary ?? this.currentEmployeeSalary,
      holidays: holidays ?? this.holidays,
      leaves: leaves ?? this.leaves,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      selectedYear: selectedYear ?? this.selectedYear,
      selectedUserId: clearSelectedUser ? null : (selectedUserId ?? this.selectedUserId),
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class SalaryNotifier extends Notifier<SalaryState> with FetchCacheMixin {
  @override
  SalaryState build() {
    final now = DateTime.now();
    return SalaryState(
      selectedMonth: now.month,
      selectedYear: now.year,
    );
  }

  void setSelectedPeriod(int month, int year) {
    state = state.copyWith(selectedMonth: month, selectedYear: year);
    fetchOrgSalaryReport(month: month, year: year, force: true);
    if (state.selectedUserId != null) {
      fetchCalculation(state.selectedUserId!, month: month, year: year, force: true);
    }
  }

  void setSelectedUser(String? userId) {
    if (userId == null) {
      state = state.copyWith(clearSelectedUser: true);
    } else {
      state = state.copyWith(selectedUserId: userId);
      fetchCalculation(userId, month: state.selectedMonth, year: state.selectedYear, force: true);
      fetchEmployeeSalaryProfile(userId);
    }
  }

  Future<void> fetchOrgSalaryReport({int? month, int? year, bool force = false}) async {
    final m = month ?? state.selectedMonth;
    final y = year ?? state.selectedYear;

    if (!shouldFetch(force: force, hasData: state.orgReport != null)) return;

    markFetchStarted();
    state = state.copyWith(isLoading: true, clearError: true);

    final users = ref.read(userManagementProvider);
    final curUser = ref.read(authProvider).currentUser;
    if (curUser != null) {
      AttendanceSalaryMockStore.instance.syncUser(curUser);
    }
    AttendanceSalaryMockStore.instance.syncUsers(users);

    try {
      final repo = ref.read(salaryRepositoryProvider);
      final report = await repo.getOrgSalaryReport(m, y, users);
      markFetchCompleted();
      state = state.copyWith(orgReport: report, isLoading: false);
    } catch (e) {
      markFetchCompleted();
      debugPrint('[SalaryNotifier] Org report network note, using fallback: $e');
      final fallback = await AttendanceSalaryMockStore.instance.getOrgSalaryReport(m, y, users);
      state = state.copyWith(orgReport: fallback, isLoading: false, clearError: true);
    }
  }

  Future<void> fetchCalculation(String userId, {int? month, int? year, bool force = false}) async {
    final m = month ?? state.selectedMonth;
    final y = year ?? state.selectedYear;

    if (!shouldFetch(force: force, hasData: state.currentCalculation != null && state.currentCalculation!.userId == userId)) return;

    markFetchStarted();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = ref.read(salaryRepositoryProvider);
      final calc = await repo.calculateSalary(userId, m, y);
      markFetchCompleted();
      state = state.copyWith(currentCalculation: calc, isLoading: false, clearError: true);
    } catch (e) {
      markFetchCompleted();
      debugPrint('[SalaryNotifier] Salary calculation network note, using fallback: $e');
      final fallback = await AttendanceSalaryMockStore.instance.calculateSalary(userId, m, y);
      state = state.copyWith(currentCalculation: fallback, isLoading: false, clearError: true);
    }
  }

  Future<void> fetchEmployeeSalaryProfile(String userId) async {
    try {
      final repo = ref.read(salaryRepositoryProvider);
      final profile = await repo.getEmployeeSalary(userId);
      state = state.copyWith(currentEmployeeSalary: profile);
    } catch (e) {
      debugPrint('[SalaryNotifier] Error fetching employee salary profile: $e');
    }
  }

  Future<bool> setEmployeeSalary(
    String userId,
    double monthlySalary, {
    int standardWorkingDays = 22,
    String currency = 'BDT',
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final repo = ref.read(salaryRepositoryProvider);
      final updated = await repo.setEmployeeSalary(
        userId,
        monthlySalary,
        standardWorkingDays: standardWorkingDays,
        currency: currency,
      );
      state = state.copyWith(currentEmployeeSalary: updated, isSubmitting: false);
      // Invalidate calculations so fresh daily rate & deductions are re-evaluated
      invalidateCache();
      await fetchCalculation(userId, month: state.selectedMonth, year: state.selectedYear, force: true);
      await fetchOrgSalaryReport(month: state.selectedMonth, year: state.selectedYear, force: true);
      return true;
    } catch (e) {
      debugPrint('[SalaryNotifier] Error setting employee salary: $e');
      state = state.copyWith(isSubmitting: false, errorMessage: 'Failed to update employee salary: $e');
      return false;
    }
  }

  Future<bool> saveCalculation(String userId, {String? notes}) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final repo = ref.read(salaryRepositoryProvider);
      final success = await repo.saveCalculation(
        userId,
        state.selectedMonth,
        state.selectedYear,
        notes: notes,
      );
      state = state.copyWith(isSubmitting: false);
      if (success) {
        invalidateCache();
        await fetchCalculation(userId, month: state.selectedMonth, year: state.selectedYear, force: true);
      }
      return success;
    } catch (e) {
      debugPrint('[SalaryNotifier] Error saving calculation: $e');
      state = state.copyWith(isSubmitting: false, errorMessage: 'Failed to save salary calculation: $e');
      return false;
    }
  }

  Future<void> fetchHolidays([int? year]) async {
    try {
      final repo = ref.read(salaryRepositoryProvider);
      final list = await repo.getHolidays(year ?? state.selectedYear);
      state = state.copyWith(holidays: list);
    } catch (e) {
      debugPrint('[SalaryNotifier] Error fetching holidays: $e');
    }
  }

  Future<bool> addHoliday(String date, String name, {bool isRecurring = false}) async {
    try {
      final repo = ref.read(salaryRepositoryProvider);
      await repo.addHoliday(date: date, name: name, isRecurring: isRecurring);
      await fetchHolidays();
      invalidateCache();
      return true;
    } catch (e) {
      debugPrint('[SalaryNotifier] Error adding holiday: $e');
      return false;
    }
  }

  Future<bool> deleteHoliday(String id) async {
    try {
      final repo = ref.read(salaryRepositoryProvider);
      await repo.deleteHoliday(id);
      await fetchHolidays();
      invalidateCache();
      return true;
    } catch (e) {
      debugPrint('[SalaryNotifier] Error deleting holiday: $e');
      return false;
    }
  }

  Future<void> fetchLeaves({String? userId, int? month, int? year}) async {
    try {
      final repo = ref.read(salaryRepositoryProvider);
      final list = await repo.getLeaves(
        userId: userId,
        month: month ?? state.selectedMonth,
        year: year ?? state.selectedYear,
      );
      state = state.copyWith(leaves: list);
    } catch (e) {
      debugPrint('[SalaryNotifier] Error fetching leaves: $e');
    }
  }

  Future<bool> addLeave({
    required String userId,
    required String startDate,
    required String endDate,
    required String leaveType,
    String? reason,
  }) async {
    try {
      final repo = ref.read(salaryRepositoryProvider);
      await repo.addLeave(
        userId: userId,
        startDate: startDate,
        endDate: endDate,
        leaveType: leaveType,
        reason: reason,
      );
      await fetchLeaves(userId: userId);
      invalidateCache();
      return true;
    } catch (e) {
      debugPrint('[SalaryNotifier] Error adding leave: $e');
      return false;
    }
  }

  Future<bool> addAdjustment({
    required String userId,
    required String type,
    required double amount,
    required String reason,
  }) async {
    try {
      final repo = ref.read(salaryRepositoryProvider);
      await repo.addAdjustment(
        userId: userId,
        adjustmentType: type,
        amount: amount,
        reason: reason,
        month: state.selectedMonth,
        year: state.selectedYear,
      );
      invalidateCache();
      await fetchCalculation(userId, month: state.selectedMonth, year: state.selectedYear, force: true);
      return true;
    } catch (e) {
      debugPrint('[SalaryNotifier] Error adding adjustment: $e');
      return false;
    }
  }
}

final salaryProvider = NotifierProvider<SalaryNotifier, SalaryState>(SalaryNotifier.new);
