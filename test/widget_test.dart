import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracking_prd/main.dart';
import 'package:expense_tracking_prd/models/user_role.dart';
import 'package:expense_tracking_prd/state/auth_provider.dart';
import 'package:expense_tracking_prd/state/expense_provider.dart';
import 'package:expense_tracking_prd/state/project_provider.dart';

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
}
