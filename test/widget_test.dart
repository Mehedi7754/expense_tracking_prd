import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracking_prd/main.dart';
import 'package:expense_tracking_prd/core/config/app_env.dart';
import 'package:expense_tracking_prd/core/network/api_client.dart';
import 'package:expense_tracking_prd/core/network/api_endpoints.dart';
import 'package:expense_tracking_prd/models/expense_model.dart';
import 'package:expense_tracking_prd/models/project_model.dart';
import 'package:expense_tracking_prd/models/user_role.dart';
import 'package:expense_tracking_prd/state/auth_provider.dart';
import 'package:expense_tracking_prd/state/expense_provider.dart';
import 'package:expense_tracking_prd/state/project_provider.dart';
import 'package:expense_tracking_prd/state/settings_provider.dart';

void main() {
  testWidgets('App smoke test initializes and settles properly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SpendWiseApp(),
      ),
    );

    // Pump to settle splash animation & auth check timer
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Confirm root SpendWiseApp is active
    expect(find.byType(SpendWiseApp), findsOneWidget);
  });

  test('Domain Model and Role-based permissions test', () {
    final container = ProviderContainer();

    // Verify initial auth state starts unauthenticated (no hardcoded backdoor)
    final initialAuth = container.read(authProvider);
    expect(initialAuth.isAuthenticated, false);
    expect(initialAuth.currentUser, isNull);

    // Switch to Project Member (Fahim)
    container.read(authProvider.notifier).switchRole(UserRole.projectMember);
    final auth = container.read(authProvider);
    expect(auth.isAuthenticated, true);
    expect(auth.currentUser?.role, UserRole.projectMember);

    // Verify projects and expenses providers are pre-seeded with Bangladesh consultancy data
    final projects = container.read(projectProvider);
    expect(projects.isNotEmpty, true);

    final expenses = container.read(expenseProvider);
    expect(expenses.isNotEmpty, true);

    // Test role switching to Project Manager
    container.read(authProvider.notifier).switchRole(UserRole.projectManager);
    expect(container.read(authProvider).currentUser?.role, UserRole.projectManager);

    // Test role switching to Finance
    container.read(authProvider.notifier).switchRole(UserRole.finance);
    expect(container.read(authProvider).currentUser?.role, UserRole.finance);

    // Test role switching to Main Admin
    container.read(authProvider.notifier).switchRole(UserRole.mainAdmin);
    expect(container.read(authProvider).currentUser?.role, UserRole.mainAdmin);

    // Test role switching to Viewer
    container.read(authProvider.notifier).switchRole(UserRole.viewer);
    expect(container.read(authProvider).currentUser?.role, UserRole.viewer);
  });

  group('Environment Security & Configuration Tests', () {
    test('AppEnv correctly loads values from environment without hardcoded fallback URLs', () {
      AppEnv.initializeForTesting({
        'ENVIRONMENT': 'development',
        'API_BASE_URL': 'https://api.spendwise.internal/api/v1',
        'API_TIMEOUT_SECONDS': '45',
        'SAMPLE_AVATAR_URL': 'https://cdn.example.com/avatar.png',
      });

      expect(AppEnv.environment, 'development');
      expect(AppEnv.isDevelopment, true);
      expect(AppEnv.apiBaseUrl, 'https://api.spendwise.internal/api/v1');
      expect(AppEnv.timeoutSeconds, 45);
      expect(AppEnv.sampleAvatarUrl, 'https://cdn.example.com/avatar.png');

      // Test ApiEndpoints dynamic resolution
      expect(ApiEndpoints.login, 'https://api.spendwise.internal/api/v1/auth/login');
      expect(ApiEndpoints.expenses, 'https://api.spendwise.internal/api/v1/expenses');
      expect(ApiEndpoints.projects, 'https://api.spendwise.internal/api/v1/projects');
      expect(ApiEndpoints.auditLogs, 'https://api.spendwise.internal/api/v1/audit-logs');
    });

    test('ApiClient redacts sensitive data and prevents credential leakage in logs', () {
      final input = {
        'username': 'eleanor.vance',
        'password': 'SuperSecretPassword123!',
        'token': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9',
        'secret': 'api_secret_key_abc',
        'user': {
          'id': 'usr_adm_01',
          'access_token': 'secret_access_token',
        },
      };

      final redacted = ApiClient.redactSensitiveData(input);
      expect(redacted['username'], 'eleanor.vance');
      expect(redacted['password'], '***REDACTED***');
      expect(redacted['token'], '***REDACTED***');
      expect(redacted['secret'], '***REDACTED***');
      expect((redacted['user'] as Map)['access_token'], '***REDACTED***');
      expect((redacted['user'] as Map)['id'], 'usr_adm_01');
    });
  });

  group('Project Progress Tracking Tests', () {
    test('Role permission canUpdateProjectProgress is restricted to Admin and Manager', () {
      expect(UserRole.mainAdmin.canUpdateProjectProgress, true);
      expect(UserRole.projectManager.canUpdateProjectProgress, true);
      expect(UserRole.finance.canUpdateProjectProgress, false);
      expect(UserRole.projectMember.canUpdateProjectProgress, false);
      expect(UserRole.viewer.canUpdateProjectProgress, false);
    });

    test('ProjectProgressStage maps correctly according to progress percentage thresholds', () {
      final container = ProviderContainer();
      final base = container.read(projectProvider).first;

      final pNotStarted = base.copyWith(progressPercentage: 0.0);
      expect(pNotStarted.progressStage, ProjectProgressStage.notStarted);
      expect(pNotStarted.progressStage.displayName, 'Not Started');

      final pInProgress1 = base.copyWith(progressPercentage: 1.0);
      expect(pInProgress1.progressStage, ProjectProgressStage.inProgress);
      expect(pInProgress1.progressStage.displayName, 'In Progress');

      final pInProgress74 = base.copyWith(progressPercentage: 74.0);
      expect(pInProgress74.progressStage, ProjectProgressStage.inProgress);

      final pNearCompletion75 = base.copyWith(progressPercentage: 75.0);
      expect(pNearCompletion75.progressStage, ProjectProgressStage.nearCompletion);
      expect(pNearCompletion75.progressStage.displayName, 'Near Completion');

      final pNearCompletion99 = base.copyWith(progressPercentage: 99.0);
      expect(pNearCompletion99.progressStage, ProjectProgressStage.nearCompletion);

      final pCompleted = base.copyWith(progressPercentage: 100.0);
      expect(pCompleted.progressStage, ProjectProgressStage.completed);
      expect(pCompleted.progressStage.displayName, 'Completed');
    });

    test('ProjectNotifier updateProjectProgress updates percentage and audit metadata', () {
      final container = ProviderContainer();
      final projectsBefore = container.read(projectProvider);
      final targetProject = projectsBefore.first;

      container.read(projectProvider.notifier).updateProjectProgress(
            projectId: targetProject.id,
            progressPercentage: 88.5,
            updatedById: 'usr_adm_01',
            updatedByName: 'Eleanor Vance',
          );

      final projectsAfter = container.read(projectProvider);
      final updated = projectsAfter.firstWhere((p) => p.id == targetProject.id);

      expect(updated.progressPercentage, 88.5);
      expect(updated.progressStage, ProjectProgressStage.nearCompletion);
      expect(updated.progressUpdatedById, 'usr_adm_01');
      expect(updated.progressUpdatedByName, 'Eleanor Vance');
      expect(updated.progressUpdatedAt, isNotNull);
    });
  });

  group('Project Cost Tax Calculation Tests', () {
    test('ExpenseModel correctly calculates baseCost, taxAmount, and totalCost', () {
      const base = 50000.0;
      const rate = 15.0; // 15%
      final tax = base * (rate / 100.0); // 7500
      final total = base + tax; // 57500

      final expense = ExpenseModel(
        id: 'exp_tax_test',
        employeeId: 'usr_01',
        employeeName: 'Tester',
        projectId: 'proj_01',
        projectName: 'Test Project',
        amount: total,
        baseCost: base,
        taxRate: rate,
        taxAmount: tax,
        categoryId: 'cat_01',
        categoryName: 'Equipment',
        categoryIcon: 'hardware',
        note: 'High performance servers',
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );

      expect(expense.baseCost, 50000.0);
      expect(expense.taxRate, 15.0);
      expect(expense.taxAmount, 7500.0);
      expect(expense.amount, 57500.0);
      expect(expense.totalCost, 57500.0);
      expect(expense.hasTax, true);
    });

    test('ExpenseNotifier submitExpense records baseCost, taxRate, taxAmount, and total cost', () {
      final container = ProviderContainer();
      final notifier = container.read(expenseProvider.notifier);

      notifier.submitExpense(
        employeeId: 'usr_emp_01',
        employeeName: 'Fahim Ahmed',
        projectId: 'proj_01',
        projectName: 'Enterprise Cloud ERP Platform',
        amount: 23000.0,
        baseCost: 20000.0,
        taxRate: 15.0,
        taxAmount: 3000.0,
        categoryId: 'cat_equip',
        categoryName: 'Equipment',
        categoryIcon: 'hardware',
        note: 'Server rack switches',
        date: DateTime.now(),
        hasReceipt: true,
      );

      final expenses = container.read(expenseProvider);
      final submitted = expenses.first;

      expect(submitted.baseCost, 20000.0);
      expect(submitted.taxRate, 15.0);
      expect(submitted.taxAmount, 3000.0);
      expect(submitted.amount, 23000.0);
      expect(submitted.totalCost, 23000.0);
      expect(submitted.hasTax, true);
    });

    test('SettingsNotifier allows authorized tax rates configuration', () {
      final container = ProviderContainer();
      final settingsNotifier = container.read(settingsProvider.notifier);

      expect(container.read(settingsProvider).availableTaxRates, contains(5.0));

      // Add custom tax rate
      settingsNotifier.addTaxRate(12.5);
      expect(container.read(settingsProvider).availableTaxRates, contains(12.5));

      // Remove tax rate
      settingsNotifier.removeTaxRate(12.5);
      expect(container.read(settingsProvider).availableTaxRates.contains(12.5), false);

      // Cannot remove 0% No Tax rate
      settingsNotifier.removeTaxRate(0.0);
      expect(container.read(settingsProvider).availableTaxRates, contains(0.0));
    });

    test('Tax calculation: 1000 entered with 5% tax adds 950 to project, with 50 VAT and 1000 invoice total', () {
      final totalEntered = 1000.0;
      final rate = 5.0;
      final taxAmount = totalEntered * (rate / 100.0);
      final netCost = totalEntered - taxAmount;

      final expense = ExpenseModel(
        id: 'exp_tax_deduct_test',
        employeeId: 'usr_emp_01',
        employeeName: 'Fahim Ahmed',
        projectId: 'proj_01',
        projectName: 'Enterprise Cloud ERP Platform',
        amount: netCost,
        baseCost: netCost,
        taxRate: rate,
        taxAmount: taxAmount,
        categoryId: 'cat_food',
        categoryName: 'Food',
        categoryIcon: 'meal',
        note: 'Team sprint lunch',
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );

      expect(expense.amount, 950.0);
      expect(expense.totalCost, 1000.0);
      expect(expense.taxRate, 5.0);
      expect(expense.taxAmount, 50.0);
      expect(expense.baseCost, 950.0);
      expect(expense.hasTax, true);
    });
  });
}
