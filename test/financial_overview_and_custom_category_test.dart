import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracking_prd/models/project_model.dart';
import 'package:expense_tracking_prd/models/user_role.dart';
import 'package:expense_tracking_prd/screens/projects/project_detail_screen.dart';
import 'package:expense_tracking_prd/screens/projects/add_edit_project_screen.dart';
import 'package:expense_tracking_prd/state/auth_provider.dart';
import 'package:expense_tracking_prd/state/project_provider.dart';
import 'package:expense_tracking_prd/state/expense_provider.dart';
import 'package:expense_tracking_prd/state/user_management_provider.dart';
import 'test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Custom Category and Financial Overview Tests', () {
    test('ProjectModel serializes and deserializes dynamic custom categories correctly', () {
      final project = ProjectModel(
        id: 'proj_custom_01',
        projectId: 'PRJ-2026-999',
        name: 'Metro Line Feasibility',
        description: 'Comprehensive transport network study',
        client: 'Ministry of Road Transport',
        grossProjectValue: 2000000.0,
        expectedNetRevenue: 1800000.0,
        amountReceivable: 1000000.0,
        budget: 1300000.0,
        categoryBudgets: {
          'equipment': 200000.0,
          'transportation': 150000.0,
          'food': 50000.0,
          'accommodation': 100000.0,
          'officecost': 100000.0,
          'officebenefit': 180000.0,
          'Survey Equipment': 75000.0,
          'Consultant Fee': 120000.0,
        },
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 12, 31),
        teamMemberIds: ['usr_001'],
      );

      final json = project.toJson();
      final parsed = ProjectModel.fromJson(json);

      expect(parsed.categoryBudgets['equipment'], 200000.0);
      expect(parsed.categoryBudgets['Survey Equipment'], 75000.0);
      expect(parsed.categoryBudgets['Consultant Fee'], 120000.0);
    });

    testWidgets('ProjectDetailScreen renders 4 clear 2-word labels at the top and Needed to Finish is editable', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer();
      container.read(authProvider.notifier).switchRole(UserRole.mainAdmin);
      container.read(projectProvider.notifier).setProjects(TestFixtures.testProjects);
      container.read(expenseProvider.notifier).setExpenses(TestFixtures.testExpenses);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ProjectDetailScreen(projectId: 'proj_01'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the 4 short 2-word metrics exist
      expect(find.text('TOTAL BUDGET'), findsOneWidget);
      expect(find.text('TOTAL SPENT'), findsOneWidget);
      expect(find.text('NEEDED TO FINISH'), findsOneWidget);
      expect(find.text('AFTER-TAX PROFIT'), findsOneWidget);

      // Verify Needed to Finish can be tapped to open dialog
      await tester.tap(find.text('NEEDED TO FINISH'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Needed to Finish'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Verify Update Budget button opens dialog
      await tester.tap(find.text('Budget'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Update Project Budget'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('AddEditProjectScreen shows Add Category button and adds dynamic category', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer();
      container.read(authProvider.notifier).switchRole(UserRole.mainAdmin);
      container.read(projectProvider.notifier).setProjects(TestFixtures.testProjects);
      container.read(userManagementProvider.notifier).setUsers(TestFixtures.testUsers);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AddEditProjectScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll to Add Category button using scrollUntilVisible
      final addCatFinder = find.text('Add Category');
      await tester.scrollUntilVisible(addCatFinder, 300, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(addCatFinder, findsOneWidget);

      // Tap Add Category
      await tester.tap(addCatFinder);
      await tester.pumpAndSettle();

      // Verify Add Category dialog opened
      expect(find.text('Add Budget Category'), findsOneWidget);

      // Enter custom category details
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, 'Special Permits');
      await tester.enterText(textFields.last, '45000');

      // Tap confirm button in dialog
      final confirmBtn = find.widgetWithText(ElevatedButton, 'Add Category');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Verify 'Special Permits' category is added
      expect(find.text('Special Permits'), findsOneWidget);
      expect(find.text('45000'), findsOneWidget);
    });
  });
}
