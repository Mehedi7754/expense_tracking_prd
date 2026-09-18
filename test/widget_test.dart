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

    // Verify initial auth state starts unauthenticated (showing Splash -> Login)
    final initialAuth = container.read(authProvider);
    expect(initialAuth.isAuthenticated, false);
    expect(initialAuth.currentUser, null);

    // Switch to employee or perform login
    container.read(authProvider.notifier).switchRole(UserRole.employee);
    final auth = container.read(authProvider);
    expect(auth.isAuthenticated, true);
    expect(auth.currentUser?.role, UserRole.employee);

    // Verify projects and expenses providers are pre-seeded
    final projects = container.read(projectProvider);
    expect(projects.isNotEmpty, true);

    final expenses = container.read(expenseProvider);
    expect(expenses.isNotEmpty, true);

    // Test role switching to Manager
    container.read(authProvider.notifier).switchRole(UserRole.manager);
    expect(container.read(authProvider).currentUser?.role, UserRole.manager);

    // Test role switching to Finance
    container.read(authProvider.notifier).switchRole(UserRole.finance);
    expect(container.read(authProvider).currentUser?.role, UserRole.finance);

    // Test role switching to Administrator
    container.read(authProvider.notifier).switchRole(UserRole.admin);
    expect(container.read(authProvider).currentUser?.role, UserRole.admin);
  });
}
