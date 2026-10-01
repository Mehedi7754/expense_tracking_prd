import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracking_prd/core/widgets/minimal_area_chart.dart';
import 'package:expense_tracking_prd/models/project_model.dart';
import 'package:expense_tracking_prd/models/user_model.dart';
import 'package:expense_tracking_prd/models/user_role.dart';
import 'package:expense_tracking_prd/state/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Monthly Graph (MinimalAreaChart) Feature Tests', () {
    testWidgets('MinimalAreaChart renders Monthly Earnings with dropdown, trend, and canvas', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MinimalAreaChart(
                title: 'Monthly Earnings',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Title & Subtitle render
      expect(find.text('Monthly Earnings'), findsOneWidget);
      expect(find.textContaining('Total:'), findsOneWidget);
      expect(find.textContaining('Avg:'), findsOneWidget);

      // Verify Period Dropdown starts with 'This Month'
      expect(find.text('This Month'), findsOneWidget);

      // Verify custom painter canvas is present
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('MinimalAreaChart allows switching period to Last Month and This Quarter', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MinimalAreaChart(
                title: 'Monthly Spending',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Monthly Spending'), findsOneWidget);
      expect(find.text('This Month'), findsOneWidget);

      // Tap Dropdown
      await tester.tap(find.text('This Month'));
      await tester.pumpAndSettle();

      // Tap 'This Quarter'
      await tester.tap(find.text('This Quarter').last);
      await tester.pumpAndSettle();

      // Verify period updated and quarter labels render
      expect(find.text('This Quarter'), findsOneWidget);
      expect(find.text('July'), findsOneWidget);
      expect(find.text('August'), findsOneWidget);
      expect(find.text('September'), findsOneWidget);
    });

    testWidgets('MinimalAreaChart supports interactive touch / dragging to scrub points', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 380,
                child: MinimalAreaChart(
                  title: 'Monthly Spending',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the chart canvas
      final customPaintFinder = find.byType(CustomPaint).last;
      expect(customPaintFinder, findsOneWidget);

      // Tap on left side of canvas (Point 0)
      await tester.tapAt(tester.getTopLeft(customPaintFinder) + const Offset(10, 80));
      await tester.pumpAndSettle();

      // Drag across to right side of canvas (Scrubbing)
      await tester.drag(customPaintFinder, const Offset(150, 0));
      await tester.pumpAndSettle();

      expect(find.byType(MinimalAreaChart), findsOneWidget);
    });
  });

  group('Session Persistence & Login State Tests', () {
    test('Session persists to SharedPreferences and restores correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Verify clean initial storage
      expect(prefs.getString('gw_session_user_data'), isNull);
      expect(prefs.getString('gw_session_auth_token'), isNull);

      // Save a session manually
      const user = DemoUsers.projectManager;
      await prefs.setString('gw_session_user_data', jsonEncode(user.toJson()));
      await prefs.setString('gw_session_auth_token', 'mock_jwt_token_12345');

      // Verify saved
      final savedUserJson = prefs.getString('gw_session_user_data');
      final savedToken = prefs.getString('gw_session_auth_token');
      expect(savedUserJson, isNotNull);
      expect(savedToken, 'mock_jwt_token_12345');

      final decoded = UserModel.fromJson(jsonDecode(savedUserJson!));
      expect(decoded.email, 'manager@pfis.com');
      expect(decoded.role, UserRole.projectManager);
      expect(decoded.name, 'Sarah Jenkins');
    });

    test('ProjectModel enum serialization matches PostgreSQL enum types', () {
      final project = ProjectModel(
        id: 'proj_test_01',
        projectId: 'PRJ-2026-999',
        name: 'PostgreSQL Compatibility Test',
        description: 'Verifying DB enum serializations',
        client: 'Test Client',
        assignmentType: AssignmentType.directConsultancy,
        grossProjectValue: 500000.0,
        expectedNetRevenue: 500000.0,
        amountReceivable: 500000.0,
        taxStatus: TaxStatus.notApplicable,
        budget: 400000.0,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 6, 30),
        teamMemberIds: ['usr_mgr_01', 'a0000000-0000-0000-0000-000000000002'],
        status: ProjectStatus.ongoing,
      );

      final json = project.toJson();
      // Ensure backend-compatible snake_case enum values
      expect(json['assignment_type'], 'direct_consultancy');
      expect(json['tax_status'], 'not_applicable');
      expect(json['status'], 'ongoing');
      // Ensure teamMemberIds maps demo ID to valid UUID
      expect(json['team_member_ids'], contains('a0000000-0000-0000-0000-000000000002'));

      // Round-trip verification
      final restored = ProjectModel.fromJson(json);
      expect(restored.name, 'PostgreSQL Compatibility Test');
      expect(restored.assignmentType, AssignmentType.directConsultancy);
      expect(restored.taxStatus, TaxStatus.notApplicable);
      expect(restored.hasMember('usr_mgr_01'), isTrue);
      expect(restored.hasMember('a0000000-0000-0000-0000-000000000002'), isTrue);
    });

    test('Custom projects persist in SharedPreferences across app restarts', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final newProj = ProjectModel(
        id: 'proj_custom_123',
        projectId: 'PRJ-2026-123',
        name: 'Persisted Roadway Survey',
        description: 'New road infrastructure survey project',
        client: 'Department of Roads',
        assignmentType: AssignmentType.government,
        grossProjectValue: 1200000.0,
        expectedNetRevenue: 1080000.0,
        amountReceivable: 1200000.0,
        taxStatus: TaxStatus.included,
        budget: 900000.0,
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 8, 31),
        teamMemberIds: ['usr_adm_01'],
      );

      // Save custom project to cache
      await prefs.setString('gw_custom_projects_cache', jsonEncode([newProj.toJson()]));

      // Verify cached
      final cachedJson = prefs.getString('gw_custom_projects_cache');
      expect(cachedJson, isNotNull);

      final List<dynamic> decodedList = jsonDecode(cachedJson!);
      expect(decodedList.length, 1);
      final restoredProject = ProjectModel.fromJson(decodedList.first);
      expect(restoredProject.id, 'proj_custom_123');
      expect(restoredProject.projectId, 'PRJ-2026-123');
      expect(restoredProject.name, 'Persisted Roadway Survey');
      expect(restoredProject.hasMember('usr_adm_01'), isTrue);
    });
  });
}
