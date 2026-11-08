import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/attendance_repository.dart';
import 'attendance_provider.dart';

const _kAttendanceSettingsKey = 'gw_attendance_settings_json_v3';
const _kOldMorningEndKey = 'gw_attendance_settings_morning_end_hour';

/// Represents a configurable work shift with its own timing window, break time, and off-days.
class AttendanceShift {
  final String id;
  final String name;
  final int morningStartHour;   // Shift Start
  final int morningEndHour;     // Legacy fallback / Break Start
  final int afternoonStartHour; // Legacy fallback / Break End
  final int afternoonEndHour;   // Shift End
  final int breakStartHour;     // Break Time From
  final int breakEndHour;       // Break Time To
  final List<int> weekendDays;  // Specific weekly off-days for this shift: 1=Mon..7=Sun
  final bool isDefault;

  const AttendanceShift({
    required this.id,
    required this.name,
    this.morningStartHour = 9,
    this.morningEndHour = 13,
    this.afternoonStartHour = 14,
    this.afternoonEndHour = 18,
    this.breakStartHour = 13,
    this.breakEndHour = 14,
    this.weekendDays = const [5, 6], // Default Friday & Saturday in BD
    this.isDefault = false,
  });

  AttendanceShift copyWith({
    String? id,
    String? name,
    int? morningStartHour,
    int? morningEndHour,
    int? afternoonStartHour,
    int? afternoonEndHour,
    int? breakStartHour,
    int? breakEndHour,
    List<int>? weekendDays,
    bool? isDefault,
  }) {
    return AttendanceShift(
      id: id ?? this.id,
      name: name ?? this.name,
      morningStartHour: morningStartHour ?? this.morningStartHour,
      morningEndHour: morningEndHour ?? (breakStartHour ?? this.morningEndHour),
      afternoonStartHour: afternoonStartHour ?? (breakEndHour ?? this.afternoonStartHour),
      afternoonEndHour: afternoonEndHour ?? this.afternoonEndHour,
      breakStartHour: breakStartHour ?? this.breakStartHour,
      breakEndHour: breakEndHour ?? this.breakEndHour,
      weekendDays: weekendDays ?? this.weekendDays,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'morningStartHour': morningStartHour,
        'morningEndHour': morningEndHour,
        'afternoonStartHour': afternoonStartHour,
        'afternoonEndHour': afternoonEndHour,
        'breakStartHour': breakStartHour,
        'breakEndHour': breakEndHour,
        'weekendDays': weekendDays,
        'isDefault': isDefault,
      };

  factory AttendanceShift.fromJson(Map<String, dynamic> json) {
    List<int> weekends = const [5, 6];
    if (json['weekendDays'] != null && json['weekendDays'] is List) {
      weekends = (json['weekendDays'] as List).map((e) => (e as num).toInt()).toList();
    }
    final mEnd = (json['morningEndHour'] as num?)?.toInt() ?? 13;
    final aStart = (json['afternoonStartHour'] as num?)?.toInt() ?? 14;
    final bStart = (json['breakStartHour'] as num?)?.toInt() ?? mEnd;
    final bEnd = (json['breakEndHour'] as num?)?.toInt() ?? aStart;

    return AttendanceShift(
      id: json['id'] as String? ?? 'shift_default',
      name: json['name'] as String? ?? 'General Shift',
      morningStartHour: (json['morningStartHour'] as num?)?.toInt() ?? 9,
      morningEndHour: bStart,
      afternoonStartHour: bEnd,
      afternoonEndHour: (json['afternoonEndHour'] as num?)?.toInt() ?? 18,
      breakStartHour: bStart,
      breakEndHour: bEnd,
      weekendDays: weekends,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}

/// Comprehensive Attendance & Shift Settings State.
class AttendanceSettingsState {
  final int morningStartHour;
  final int morningEndHour;
  final int afternoonStartHour;
  final int afternoonEndHour;
  final int breakStartHour;
  final int breakEndHour;

  /// Global default weekend off days (1=Mon..7=Sun)
  final List<int> weekendDays;

  /// Salary Deduction Mode: 'rate_based' (proportional daily rate) or 'fixed_amount' (fixed BDT)
  final String deductionType;

  /// Whether salary deductions for missed/half-day attendance are enabled.
  final bool isDeductionEnabled;

  /// Full-day deduction multiplier (e.g. 1.0) or fixed amount (e.g. 1000.0)
  final double fullDayDeductionAmount;

  /// Half-day deduction multiplier (e.g. 0.5) or fixed amount (e.g. 500.0)
  final double halfDayDeductionAmount;

  /// Configured Shifts
  final List<AttendanceShift> shifts;

  /// Mapping of employee ID to assigned shift ID ({userId: shiftId})
  final Map<String, String> userShifts;

  /// Grace period in minutes for late check-in
  final int gracePeriodMinutes;

  /// Office Geofencing & Location Configuration
  final double officeLatitude;
  final double officeLongitude;
  final String officeName;
  final String officeAddress;
  final double geofenceRadiusMeters;
  final bool isGeofenceEnforced;

  const AttendanceSettingsState({
    this.morningStartHour = 9,
    this.morningEndHour = 13,
    this.afternoonStartHour = 14,
    this.afternoonEndHour = 18,
    this.breakStartHour = 13,
    this.breakEndHour = 14,
    this.weekendDays = const [5, 6],
    this.deductionType = 'rate_based',
    this.isDeductionEnabled = true,
    this.fullDayDeductionAmount = 1.0,
    this.halfDayDeductionAmount = 0.5,
    this.gracePeriodMinutes = 15,
    this.officeLatitude = 23.7925,
    this.officeLongitude = 90.4078,
    this.officeName = 'Geospatial Works HQ',
    this.officeAddress = 'Road 11, Block D, Banani, Dhaka',
    this.geofenceRadiusMeters = 200.0,
    this.isGeofenceEnforced = true,
    this.shifts = const [
      AttendanceShift(
        id: 'shift_default',
        name: 'General Office Shift',
        morningStartHour: 9,
        morningEndHour: 13,
        afternoonStartHour: 14,
        afternoonEndHour: 18,
        breakStartHour: 13,
        breakEndHour: 14,
        weekendDays: [5, 6], // Fri & Sat
        isDefault: true,
      ),
      AttendanceShift(
        id: 'shift_morning',
        name: 'Early Morning Shift',
        morningStartHour: 7,
        morningEndHour: 11,
        afternoonStartHour: 12,
        afternoonEndHour: 15,
        breakStartHour: 11,
        breakEndHour: 12,
        weekendDays: [5, 6],
      ),
      AttendanceShift(
        id: 'shift_evening',
        name: 'Evening Shift',
        morningStartHour: 14,
        morningEndHour: 18,
        afternoonStartHour: 19,
        afternoonEndHour: 22,
        breakStartHour: 18,
        breakEndHour: 19,
        weekendDays: [7], // Sunday only
      ),
    ],
    this.userShifts = const {},
  });

  /// Helper to get the shift assigned to a specific user
  AttendanceShift getShiftForUser(String userId) {
    final shiftId = userShifts[userId];
    if (shiftId != null) {
      final found = shifts.where((s) => s.id == shiftId);
      if (found.isNotEmpty) return found.first;
    }
    final defaultFound = shifts.where((s) => s.isDefault);
    if (defaultFound.isNotEmpty) return defaultFound.first;
    return shifts.isNotEmpty ? shifts.first : const AttendanceShift(id: 'shift_default', name: 'General Shift');
  }

  AttendanceSettingsState copyWith({
    int? morningStartHour,
    int? morningEndHour,
    int? afternoonStartHour,
    int? afternoonEndHour,
    int? breakStartHour,
    int? breakEndHour,
    List<int>? weekendDays,
    String? deductionType,
    bool? isDeductionEnabled,
    double? fullDayDeductionAmount,
    double? halfDayDeductionAmount,
    int? gracePeriodMinutes,
    double? officeLatitude,
    double? officeLongitude,
    String? officeName,
    String? officeAddress,
    double? geofenceRadiusMeters,
    bool? isGeofenceEnforced,
    List<AttendanceShift>? shifts,
    Map<String, String>? userShifts,
  }) {
    return AttendanceSettingsState(
      morningStartHour: morningStartHour ?? this.morningStartHour,
      morningEndHour: morningEndHour ?? (breakStartHour ?? this.morningEndHour),
      afternoonStartHour: afternoonStartHour ?? (breakEndHour ?? this.afternoonStartHour),
      afternoonEndHour: afternoonEndHour ?? this.afternoonEndHour,
      breakStartHour: breakStartHour ?? this.breakStartHour,
      breakEndHour: breakEndHour ?? this.breakEndHour,
      weekendDays: weekendDays ?? this.weekendDays,
      deductionType: deductionType ?? this.deductionType,
      isDeductionEnabled: isDeductionEnabled ?? this.isDeductionEnabled,
      fullDayDeductionAmount: fullDayDeductionAmount ?? this.fullDayDeductionAmount,
      halfDayDeductionAmount: halfDayDeductionAmount ?? this.halfDayDeductionAmount,
      gracePeriodMinutes: gracePeriodMinutes ?? this.gracePeriodMinutes,
      officeLatitude: officeLatitude ?? this.officeLatitude,
      officeLongitude: officeLongitude ?? this.officeLongitude,
      officeName: officeName ?? this.officeName,
      officeAddress: officeAddress ?? this.officeAddress,
      geofenceRadiusMeters: geofenceRadiusMeters ?? this.geofenceRadiusMeters,
      isGeofenceEnforced: isGeofenceEnforced ?? this.isGeofenceEnforced,
      shifts: shifts ?? this.shifts,
      userShifts: userShifts ?? this.userShifts,
    );
  }

  Map<String, dynamic> toJson() => {
        'morningStartHour': morningStartHour,
        'morningEndHour': morningEndHour,
        'afternoonStartHour': afternoonStartHour,
        'afternoonEndHour': afternoonEndHour,
        'breakStartHour': breakStartHour,
        'breakEndHour': breakEndHour,
        'weekendDays': weekendDays,
        'deductionType': deductionType,
        'isDeductionEnabled': isDeductionEnabled,
        'fullDayDeductionAmount': fullDayDeductionAmount,
        'halfDayDeductionAmount': halfDayDeductionAmount,
        'gracePeriodMinutes': gracePeriodMinutes,
        'officeLatitude': officeLatitude,
        'officeLongitude': officeLongitude,
        'officeName': officeName,
        'officeAddress': officeAddress,
        'geofenceRadiusMeters': geofenceRadiusMeters,
        'isGeofenceEnforced': isGeofenceEnforced,
        'shifts': shifts.map((s) => s.toJson()).toList(),
        'userShifts': userShifts,
      };

  factory AttendanceSettingsState.fromJson(Map<String, dynamic> json) {
    List<int> weekend = const [5, 6];
    if (json['weekendDays'] != null && json['weekendDays'] is List) {
      weekend = (json['weekendDays'] as List).map((e) => (e as num).toInt()).toList();
    }
    final isDeductionEnabled = json['isDeductionEnabled'] as bool? ?? true;
    List<AttendanceShift> shiftList = const [
      AttendanceShift(
        id: 'shift_default',
        name: 'General Office Shift',
        morningStartHour: 9,
        morningEndHour: 13,
        afternoonStartHour: 14,
        afternoonEndHour: 18,
        breakStartHour: 13,
        breakEndHour: 14,
        weekendDays: [5, 6],
        isDefault: true,
      ),
    ];
    if (json['shifts'] != null && json['shifts'] is List) {
      shiftList = (json['shifts'] as List)
          .map((item) => AttendanceShift.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    Map<String, String> userMap = {};
    if (json['userShifts'] != null && json['userShifts'] is Map) {
      (json['userShifts'] as Map).forEach((key, value) {
        userMap[key.toString()] = value.toString();
      });
    }

    final defaultShiftIdx = shiftList.indexWhere((s) => s.isDefault || s.id == 'shift_default');
    final defaultShift = defaultShiftIdx >= 0 ? shiftList[defaultShiftIdx] : (shiftList.isNotEmpty ? shiftList.first : null);

    int morningStart = defaultShift?.morningStartHour ?? (json['morningStartHour'] as num?)?.toInt() ?? 9;
    int morningEnd = defaultShift?.morningEndHour ?? (json['morningEndHour'] as num?)?.toInt() ?? 13;
    int afternoonStart = defaultShift?.afternoonStartHour ?? (json['afternoonStartHour'] as num?)?.toInt() ?? 14;
    int afternoonEnd = defaultShift?.afternoonEndHour ?? (json['afternoonEndHour'] as num?)?.toInt() ?? 18;
    int breakStart = defaultShift?.breakStartHour ?? (json['breakStartHour'] as num?)?.toInt() ?? morningEnd;
    int breakEnd = defaultShift?.breakEndHour ?? (json['breakEndHour'] as num?)?.toInt() ?? afternoonStart;
    if (defaultShift != null && defaultShift.weekendDays.isNotEmpty) {
      weekend = defaultShift.weekendDays;
    }

    return AttendanceSettingsState(
      morningStartHour: morningStart,
      morningEndHour: morningEnd,
      afternoonStartHour: afternoonStart,
      afternoonEndHour: afternoonEnd,
      breakStartHour: breakStart,
      breakEndHour: breakEnd,
      weekendDays: weekend,
      deductionType: json['deductionType'] as String? ?? 'rate_based',
      isDeductionEnabled: isDeductionEnabled,
      fullDayDeductionAmount: (json['fullDayDeductionAmount'] as num?)?.toDouble() ?? 1.0,
      halfDayDeductionAmount: (json['halfDayDeductionAmount'] as num?)?.toDouble() ?? 0.5,
      gracePeriodMinutes: (json['gracePeriodMinutes'] as num?)?.toInt() ?? 15,
      officeLatitude: (json['officeLatitude'] as num?)?.toDouble() ?? 23.7925,
      officeLongitude: (json['officeLongitude'] as num?)?.toDouble() ?? 90.4078,
      officeName: json['officeName']?.toString() ?? 'Geospatial Works HQ',
      officeAddress: json['officeAddress']?.toString() ?? 'Road 11, Block D, Banani, Dhaka',
      geofenceRadiusMeters: (json['geofenceRadiusMeters'] as num?)?.toDouble() ?? 200.0,
      isGeofenceEnforced: json['isGeofenceEnforced'] as bool? ?? true,
      shifts: shiftList,
      userShifts: userMap,
    );
  }
}

class AttendanceSettingsNotifier extends AsyncNotifier<AttendanceSettingsState> {
  @override
  Future<AttendanceSettingsState> build() async {
    final prefs = await SharedPreferences.getInstance();
    AttendanceSettingsState initial = const AttendanceSettingsState();

    // Load from local storage
    final jsonStr = prefs.getString(_kAttendanceSettingsKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(jsonStr);
        initial = AttendanceSettingsState.fromJson(decoded);
      } catch (_) {}
    } else {
      final oldHour = prefs.getInt(_kOldMorningEndKey);
      if (oldHour != null) {
        initial = initial.copyWith(morningEndHour: oldHour, afternoonStartHour: oldHour);
      }
    }

    // Attempt sync with backend API
    try {
      final repo = ref.read(attendanceRepositoryProvider);
      final apiSettings = await repo.getAttendanceSettings();
      if (apiSettings != null) {
        initial = AttendanceSettingsState.fromJson(apiSettings);
        await prefs.setString(_kAttendanceSettingsKey, jsonEncode(initial.toJson()));
      }
    } catch (_) {}

    return initial;
  }

  Future<void> updateSettings(AttendanceSettingsState newSettings) async {
      final repo = ref.read(attendanceRepositoryProvider);
      final saved = await repo.updateAttendanceSettings(
        morningStartHour: newSettings.morningStartHour,
        morningEndHour: newSettings.morningEndHour,
        afternoonStartHour: newSettings.afternoonStartHour,
        afternoonEndHour: newSettings.afternoonEndHour,
        breakStartHour: newSettings.breakStartHour,
        breakEndHour: newSettings.breakEndHour,
        weekendDays: newSettings.weekendDays,
        deductionType: newSettings.deductionType,
        fullDayDeductionAmount: newSettings.fullDayDeductionAmount,
        halfDayDeductionAmount: newSettings.halfDayDeductionAmount,
        shifts: newSettings.shifts.map((s) => s.toJson()).toList(),
        userShifts: newSettings.userShifts,
        officeLatitude: newSettings.officeLatitude,
        officeLongitude: newSettings.officeLongitude,
        officeName: newSettings.officeName,
        officeAddress: newSettings.officeAddress,
        geofenceRadiusMeters: newSettings.geofenceRadiusMeters,
        isGeofenceEnforced: newSettings.isGeofenceEnforced,
      );
      if (!saved) throw StateError('Attendance settings were not saved');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAttendanceSettingsKey, jsonEncode(newSettings.toJson()));
      await prefs.setInt(_kOldMorningEndKey, newSettings.morningEndHour);
      state = AsyncValue.data(newSettings);
      // Immediately refresh attendance state & daily overview so UI reflects real-time off-days & shift changes
      ref.read(attendanceProvider.notifier).fetchDailyOverview(force: true);
      ref.read(attendanceProvider.notifier).fetchAttendanceRecords(force: true);
  }

  Future<void> setGeofenceSettings({
    double? officeLatitude,
    double? officeLongitude,
    String? officeName,
    String? officeAddress,
    double? geofenceRadiusMeters,
    bool? isGeofenceEnforced,
  }) async {
    final current = state.value ?? const AttendanceSettingsState();
    final updated = current.copyWith(
      officeLatitude: officeLatitude ?? current.officeLatitude,
      officeLongitude: officeLongitude ?? current.officeLongitude,
      officeName: officeName ?? current.officeName,
      officeAddress: officeAddress ?? current.officeAddress,
      geofenceRadiusMeters: geofenceRadiusMeters ?? current.geofenceRadiusMeters,
      isGeofenceEnforced: isGeofenceEnforced ?? current.isGeofenceEnforced,
    );
    await updateSettings(updated);
  }

  Future<void> setMorningEndHour(int hour) async {
    final current = state.value ?? const AttendanceSettingsState();
    final updatedShifts = current.shifts.map((s) {
      if (s.isDefault || s.id == 'shift_default') {
        return s.copyWith(morningEndHour: hour, afternoonStartHour: hour);
      }
      return s;
    }).toList();
    final updated = current.copyWith(
      morningEndHour: hour,
      afternoonStartHour: hour,
      shifts: updatedShifts,
    );
    await updateSettings(updated);
  }

  Future<void> setOfficeHours({
    required int morningStartHour,
    required int cutoffHour,
    required int afternoonEndHour,
    List<int>? weekendDays,
  }) async {
    final current = state.value ?? const AttendanceSettingsState();
    final effectiveWeekends = weekendDays ?? current.weekendDays;
    final updatedShifts = current.shifts.map((s) {
      if (s.isDefault || s.id == 'shift_default') {
        return s.copyWith(
          morningStartHour: morningStartHour,
          morningEndHour: cutoffHour,
          afternoonStartHour: cutoffHour,
          afternoonEndHour: afternoonEndHour,
          weekendDays: effectiveWeekends,
        );
      }
      return s;
    }).toList();
    final updated = current.copyWith(
      morningStartHour: morningStartHour,
      morningEndHour: cutoffHour,
      afternoonStartHour: cutoffHour,
      afternoonEndHour: afternoonEndHour,
      weekendDays: effectiveWeekends,
      shifts: updatedShifts,
    );
    await updateSettings(updated);
  }

  Future<void> setWeekendDays(List<int> weekendDays) async {
    final current = state.value ?? const AttendanceSettingsState();
    final updatedShifts = current.shifts.map((s) {
      if (s.isDefault || s.id == 'shift_default') {
        return s.copyWith(weekendDays: weekendDays);
      }
      return s;
    }).toList();
    final updated = current.copyWith(
      weekendDays: weekendDays,
      shifts: updatedShifts,
    );
    await updateSettings(updated);
  }

  Future<void> setDeductionRules({
    required String deductionType,
    required double fullDayAmount,
    required double halfDayAmount,
  }) async {
    final current = state.value ?? const AttendanceSettingsState();
    final updated = current.copyWith(
      deductionType: deductionType,
      fullDayDeductionAmount: fullDayAmount,
      halfDayDeductionAmount: halfDayAmount,
    );
    await updateSettings(updated);
  }

  Future<void> addOrUpdateShift(AttendanceShift shift) async {
    final current = state.value ?? const AttendanceSettingsState();
    final list = List<AttendanceShift>.from(current.shifts);
    final idx = list.indexWhere((s) => s.id == shift.id);
    if (idx >= 0) {
      list[idx] = shift;
    } else {
      list.add(shift);
    }
    var updated = current.copyWith(shifts: list);
    // If updating default shift or single shift, keep top-level timing synchronized
    if (shift.isDefault || shift.id == 'shift_default' || list.length == 1) {
      updated = updated.copyWith(
        morningStartHour: shift.morningStartHour,
        morningEndHour: shift.morningEndHour,
        afternoonStartHour: shift.afternoonStartHour,
        afternoonEndHour: shift.afternoonEndHour,
        breakStartHour: shift.breakStartHour,
        breakEndHour: shift.breakEndHour,
        weekendDays: shift.weekendDays,
      );
    }
    await updateSettings(updated);
  }

  Future<void> deleteShift(String shiftId) async {
    final current = state.value ?? const AttendanceSettingsState();
    // Do not delete default shift
    final target = current.shifts.where((s) => s.id == shiftId).firstOrNull;
    if (target == null || target.isDefault) return;

    final list = current.shifts.where((s) => s.id != shiftId).toList();
    // Reassign any users who had this shift back to shift_default
    final userMap = Map<String, String>.from(current.userShifts);
    userMap.removeWhere((_, sId) => sId == shiftId);

    await updateSettings(current.copyWith(shifts: list, userShifts: userMap));
  }

  Future<void> assignUserShift(String userId, String shiftId) async {
    final current = state.value ?? const AttendanceSettingsState();
    final map = Map<String, String>.from(current.userShifts);
    map[userId] = shiftId;
    await updateSettings(current.copyWith(userShifts: map));
  }

  /// Synchronous fallback helper for current morning end hour
  int get currentMorningEndHour {
    return state.when(
      data: (s) => s.morningEndHour,
      loading: () => 13,
      error: (_, __) => 13,
    );
  }
}

final attendanceSettingsProvider =
    AsyncNotifierProvider<AttendanceSettingsNotifier, AttendanceSettingsState>(
  AttendanceSettingsNotifier.new,
);
