import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

import 'package:expense_tracking_prd/core/routing/app_router.dart';
import 'package:expense_tracking_prd/core/routing/route_paths.dart';
import 'package:expense_tracking_prd/core/services/attendance_salary_mock_store.dart';
import 'package:expense_tracking_prd/core/widgets/receipt_uploader.dart';
import 'package:expense_tracking_prd/core/config/app_env.dart';
import 'package:expense_tracking_prd/screens/admin/user_management_screen.dart';
import 'package:expense_tracking_prd/screens/admin/category_management_screen.dart';
import 'package:expense_tracking_prd/screens/salary/holidays_management_screen.dart';
import 'package:expense_tracking_prd/screens/expenses/receipt_compliance_screen.dart';
import 'package:expense_tracking_prd/screens/admin/client_analysis_screen.dart';
import 'package:expense_tracking_prd/screens/attendance/widgets/member_geo_location_modal.dart';
import 'package:expense_tracking_prd/models/attendance_model.dart';
import 'package:expense_tracking_prd/models/client_model.dart';
import 'package:expense_tracking_prd/models/user_role.dart';
import 'package:expense_tracking_prd/state/auth_provider.dart';
import 'package:expense_tracking_prd/state/expense_provider.dart';
import 'package:expense_tracking_prd/state/client_provider.dart';
import 'test_fixtures.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Bug 1 & Bug 5: Weekend Attendance Status, Dashboard, and Salary Protection', () {
    test('Mock store treats Friday and Saturday as weekend with 0 missing count and 0 penalty', () async {
      final store = AttendanceSalaryMockStore.instance;
      await store.ensureInitialized();

      // Test a known Friday: 2026-10-02 was Friday
      final fridayOverview = await store.getDailyOverview('2026-10-02');
      expect(fridayOverview.isWeekend, isTrue);
      expect(fridayOverview.missingCount, equals(0));

      for (final emp in fridayOverview.employees) {
        if (emp.morning == null && emp.afternoon == null) {
          expect(emp.status, anyOf(equals('weekend'), equals('holiday')));
          expect(emp.isMissing, isFalse);
          expect(emp.isConfirmedAbsent, isFalse);
        }
      }

      // Test a known Saturday: 2026-10-03 is Saturday
      final saturdayOverview = await store.getDailyOverview('2026-10-03');
      expect(saturdayOverview.isWeekend, isTrue);
      expect(saturdayOverview.missingCount, equals(0));

      for (final emp in saturdayOverview.employees) {
        if (emp.morning == null && emp.afternoon == null) {
          expect(emp.status, anyOf(equals('weekend'), equals('holiday')));
          expect(emp.isMissing, isFalse);
          expect(emp.isConfirmedAbsent, isFalse);
        }
      }
    });

    testWidgets('MemberGeoLocationModal does not show Confirm Unpaid Absence on weekend and shows No Cut', (WidgetTester tester) async {
      final store = AttendanceSalaryMockStore.instance;
      await store.ensureInitialized();

      final saturdayOverview = await store.getDailyOverview('2026-10-03');
      final emp = saturdayOverview.employees.first;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MemberGeoLocationModal(
                  date: '2026-10-03',
                  employee: emp,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Confirm absence button must NOT be present on weekends
      expect(find.text('Confirm Unpaid Absence'), findsNothing);
      // Weekend non-working day info should be displayed
      expect(find.textContaining('non-working days'), findsOneWidget);
      expect(find.text('৳0.00 (No Cut)'), findsOneWidget);
    });
  });

  group('Bug 2 & Bug 9: Project Revenue & My Expenses Routes', () {
    test('RoutePaths defines plural revenue path and myExpenses correctly', () {
      expect(RoutePaths.addRevenuePattern, equals('/projects/:id/revenues/new'));
      expect(RoutePaths.myExpenses, equals('/expenses/my'));
    });

    test('AppRouter contains both plural and singular project revenue routes', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = container.read(routerProvider);
      final routes = router.configuration.routes;

      bool foundPluralRevenue = false;
      bool foundSingularRevenue = false;
      bool foundMyExpenses = false;
      bool foundMyExpensesLegacy = false;

      for (final route in routes) {
        if (route is GoRoute) {
          if (route.path == '/projects/:id/revenues/new') foundPluralRevenue = true;
          if (route.path == '/projects/:id/revenue/new') foundSingularRevenue = true;
          if (route.path == '/expenses/my') foundMyExpenses = true;
          if (route.path == '/expenses/my-expenses') foundMyExpensesLegacy = true;
        }
      }

      expect(foundPluralRevenue, isTrue, reason: 'Plural /projects/:id/revenues/new route must exist');
      expect(foundSingularRevenue, isTrue, reason: 'Singular /projects/:id/revenue/new alias must exist');
      expect(foundMyExpenses, isTrue, reason: 'Convention /expenses/my route must exist');
      expect(foundMyExpensesLegacy, isTrue, reason: 'Legacy /expenses/my-expenses alias must exist');
    });
  });

  group('Bug 4: Submit Expense Route Order Conflict', () {
    test('/expenses/new is declared before /expenses/:id so it is not captured as an id', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = container.read(routerProvider);
      final routes = router.configuration.routes;

      int newIndex = -1;
      int idIndex = -1;

      for (int i = 0; i < routes.length; i++) {
        final route = routes[i];
        if (route is GoRoute) {
          if (route.path == '/expenses/new') newIndex = i;
          if (route.path == '/expenses/:id') idIndex = i;
        }
      }

      expect(newIndex, greaterThanOrEqualTo(0), reason: '/expenses/new route exists');
      expect(idIndex, greaterThan(newIndex), reason: '/expenses/new must precede /expenses/:id');
    });
  });

  group('Bug 6: Relative Receipt URLs Web Host Joining', () {
    test('ReceiptUploader resolves relative paths to absolute backend URLs', () {
      const relativePath = '/uploads/expenses/receipt-test-123.jpg';
      final resolved = ReceiptUploader.resolveImageUrl(relativePath);

      expect(resolved.startsWith('http://') || resolved.startsWith('https://'), isTrue);
      expect(resolved, contains('/uploads/expenses/receipt-test-123.jpg'));
      expect(resolved, isNot(contains('/api/v1/uploads'))); // Should strip /api/v1
    });

    test('ReceiptUploader preserves already full URLs without modification', () {
      const fullUrl = 'https://s3.amazonaws.com/my-bucket/receipt.png';
      final resolved = ReceiptUploader.resolveImageUrl(fullUrl);
      expect(resolved, equals(fullUrl));
    });
  });

  group('Bug 3, 10, 11: FAB Positioning and Bottom Padding to Prevent Overlaps', () {
    testWidgets('UserManagementScreen uses endFloat FAB and ample bottom scroll padding', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: UserManagementScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.floatingActionButtonLocation, equals(FloatingActionButtonLocation.endFloat));

      final listView = tester.widget<ListView>(find.byType(ListView));
      final padding = listView.padding as EdgeInsets?;
      expect(padding != null && padding.bottom >= 100, isTrue);
    });

    testWidgets('CategoryManagementScreen has no duplicate AppBar action and ample bottom scroll padding', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CategoryManagementScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.floatingActionButtonLocation, equals(FloatingActionButtonLocation.endFloat));

      // Check that only 1 "Add Category" button exists on screen (the FAB)
      expect(find.text('Add Category'), findsOneWidget);

      final listView = tester.widget<ListView>(find.byType(ListView));
      final padding = listView.padding as EdgeInsets?;
      expect(padding != null && padding.bottom >= 100, isTrue);
    });

    testWidgets('HolidaysManagementScreen has ample bottom scroll padding to not block delete icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HolidaysManagementScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.floatingActionButtonLocation, equals(FloatingActionButtonLocation.endFloat));

      final listView = tester.widget<ListView>(find.byType(ListView));
      final padding = listView.padding as EdgeInsets?;
      expect(padding != null && padding.bottom >= 100, isTrue);
    });
  });

  group('Bug 12: Horizontal Truncation of Compliance Data Table on Mobile', () {
    testWidgets('ReceiptComplianceScreen wraps table in horizontal scroll with Scrollbar', (WidgetTester tester) async {
      tester.binding.window.physicalSizeTestValue = const Size(393, 852);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      addTearDown(() {
        tester.binding.window.clearPhysicalSizeTestValue();
        tester.binding.window.clearDevicePixelRatioTestValue();
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(authProvider.notifier).switchRole(UserRole.mainAdmin);
      container.read(expenseProvider.notifier).setExpenses(TestFixtures.testExpenses);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ReceiptComplianceScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Must find horizontal SingleChildScrollView
      final horizontalScroll = find.byWidgetPredicate(
        (widget) => widget is SingleChildScrollView && widget.scrollDirection == Axis.horizontal,
      );
      expect(horizontalScroll, findsWidgets);

      // Must find DataTable inside
      expect(find.byType(DataTable), findsWidgets);
    });
  });

  group('Bug 13: Empty Client-Level Analysis View Without Placeholder', () {
    testWidgets('ClientAnalysisScreen shows informative placeholder when no clients are available', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ClientAnalysisScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // When no client data is available, placeholder appears
      expect(find.text('No Client Data Available'), findsOneWidget);
    });

    testWidgets('ClientAnalysisScreen shows placeholder when client has no projects', (WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(clientProvider.notifier).setClients([
        const ClientModel(
          id: 'c1',
          name: 'Apex Holdings Ltd',
          contactPerson: 'Rahim',
          email: 'contact@apex.com',
          phone: '+8801700000000',
          address: 'Dhaka',
        ),
      ]);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ClientAnalysisScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Projects for Apex Holdings Ltd'), findsOneWidget);
    });
  });
}
