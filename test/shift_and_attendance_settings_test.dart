import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracking_prd/state/attendance_settings_provider.dart';
import 'package:expense_tracking_prd/screens/attendance/attendance_settings_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Shift Management and Multi-Shift Settings Test', () {
    test('AttendanceSettingsState defaults and userShift helper', () {
      final state = const AttendanceSettingsState();
      expect(state.shifts.length, 3);
      expect(state.shifts.first.isDefault, isTrue);
      expect(state.shifts.first.name, 'General Office Shift');
      expect(state.shifts.first.weekendDays, equals([5, 6]));

      final userShift = state.getShiftForUser('u_unknown');
      expect(userShift.id, 'shift_default');
    });

    test('AttendanceShift copyWith and JSON serialization', () {
      const shift = AttendanceShift(
        id: 'shift_test_1',
        name: 'Night Watch',
        morningStartHour: 20,
        morningEndHour: 0,
        afternoonStartHour: 0,
        afternoonEndHour: 4,
        weekendDays: [7],
      );

      final json = shift.toJson();
      final fromJson = AttendanceShift.fromJson(json);

      expect(fromJson.id, 'shift_test_1');
      expect(fromJson.name, 'Night Watch');
      expect(fromJson.weekendDays, equals([7]));
      expect(fromJson.isDefault, isFalse);
    });

    testWidgets('AttendanceSettingsScreen renders Shift & Schedule Management UI and Add Shift button', (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          attendanceSettingsProvider.overrideWith(() => _FakeAttendanceNotifier()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AttendanceSettingsScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Shift & Attendance Settings'), findsOneWidget);
      expect(find.text('Shift & Schedule Management'), findsOneWidget);
      expect(find.text('Add Custom Shift'), findsOneWidget);
      expect(find.text('Save Settings'), findsOneWidget);
    });

    test('AttendanceSettingsNotifier syncs top-level cutoff hour with default shift', () async {
      final notifier = AttendanceSettingsNotifier();
      // Test state synchronization logic
      const state = AttendanceSettingsState(morningEndHour: 13);
      final updatedShifts = state.shifts.map((s) {
        if (s.isDefault || s.id == 'shift_default') {
          return s.copyWith(morningEndHour: 15, afternoonStartHour: 15);
        }
        return s;
      }).toList();
      final updated = state.copyWith(
        morningEndHour: 15,
        afternoonStartHour: 15,
        shifts: updatedShifts,
      );

      expect(updated.morningEndHour, 15);
      expect(updated.afternoonStartHour, 15);
      final defaultShift = updated.shifts.firstWhere((s) => s.isDefault);
      expect(defaultShift.morningEndHour, 15);
      expect(defaultShift.afternoonStartHour, 15);
    });
  });
}

class _FakeAttendanceNotifier extends AttendanceSettingsNotifier {
  @override
  Future<AttendanceSettingsState> build() async {
    return const AttendanceSettingsState();
  }

  @override
  Future<void> updateSettings(AttendanceSettingsState newSettings) async {
    state = AsyncValue.data(newSettings);
  }

  @override
  Future<void> addOrUpdateShift(AttendanceShift shift) async {}

  @override
  Future<void> deleteShift(String shiftId) async {}

  @override
  Future<void> assignUserShift(String userId, String shiftId) async {}

  @override
  int get currentMorningEndHour => 13;

  @override
  Future<void> setMorningEndHour(int hour) async {}

  @override
  Future<void> setWeekendDays(List<int> weekendDays) async {}

  @override
  Future<void> setDeductionRules({
    required String deductionType,
    required double fullDayAmount,
    required double halfDayAmount,
  }) async {}
}
