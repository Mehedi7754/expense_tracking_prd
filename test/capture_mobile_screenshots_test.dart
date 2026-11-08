import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracking_prd/state/attendance_settings_provider.dart';
import 'package:expense_tracking_prd/screens/attendance/attendance_settings_screen.dart';
import 'package:expense_tracking_prd/screens/attendance/attendance_dashboard_screen.dart';
import 'package:expense_tracking_prd/state/auth_provider.dart';
import 'package:expense_tracking_prd/models/user_model.dart';
import 'package:expense_tracking_prd/models/user_role.dart';
import 'package:expense_tracking_prd/state/attendance_provider.dart';

class _FakeAttendanceNotifier extends AttendanceSettingsNotifier {
  @override
  Future<AttendanceSettingsState> build() async {
    return const AttendanceSettingsState();
  }
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return const AuthState(
      currentUser: UserModel(
        id: 'a0000000-0000-0000-0000-000000000002',
        name: 'Local Admin Tester',
        email: 'admin@local.test',
        role: UserRole.mainAdmin,
        department: 'Administration',
      ),
      isAuthenticated: true,
    );
  }
}

class _FakeAttendanceRecordNotifier extends AttendanceNotifier {
  @override
  AttendanceState build() {
    return const AttendanceState(
      records: [],
      selectedDate: '2026-11-08',
      isLoading: false,
    );
  }

  @override
  Future<void> fetchDailyOverview({String? date, bool force = false}) async {}

  @override
  Future<void> fetchAttendanceRecords({
    String? userId,
    String? date,
    int? month,
    int? year,
    bool force = false,
  }) async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('AttendanceSettingsScreen renders Break Time Selection in dialog', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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
          debugShowCheckedModeBanner: false,
          home: AttendanceSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify break chip
    expect(find.text('☕ Break'), findsWidgets);

    // Drag down to reveal shift card and add button
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -800));
    await tester.pumpAndSettle();

    // Tap 'Add Custom Shift'
    await tester.tap(find.text('Add Custom Shift'));
    await tester.pumpAndSettle();

    expect(find.text('Break Time Selection'), findsOneWidget);
    expect(find.text('Break From'), findsOneWidget);
    expect(find.text('Break To'), findsOneWidget);
  });

  testWidgets('AttendanceDashboardScreen renders Override action and opens Override BottomSheet', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => _FakeAuthNotifier()),
        attendanceSettingsProvider.overrideWith(() => _FakeAttendanceNotifier()),
        attendanceProvider.overrideWith(() => _FakeAttendanceRecordNotifier()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: AttendanceDashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify AppBar override action button tooltip
    expect(find.byTooltip('Override Attendance (Date Range)'), findsOneWidget);

    // Tap the override action icon
    await tester.tap(find.byTooltip('Override Attendance (Date Range)'));
    await tester.pumpAndSettle();

    // Verify bottom sheet title and options
    expect(find.text('Override Attendance'), findsOneWidget);
    expect(find.text('Date range override with off-day & holiday protection'), findsOneWidget);
    expect(find.text('Date Range'), findsOneWidget);
    // Scroll down inside the bottom sheet modal to reveal the action buttons
    await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.text('Apply Override'), findsOneWidget);
  });
}
