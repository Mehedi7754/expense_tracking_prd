import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:expense_tracking_prd/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('End-to-End full application flow test', (tester) async {
    // Start the app
    app.main();
    await tester.pumpAndSettle();

    // 1. LOGIN SCREEN
    expect(find.text('Geospatial Works'), findsOneWidget);
    
    // Tap Employee Role
    await tester.tap(find.text('Employee'));
    await tester.pumpAndSettle();

    // Login as an employee (Assuming "Elias (Engineer)" logic exists)
    // Here we find the login button (e.g. Employee Login)
    await tester.tap(find.text('Login as Elias (Engineer)'));
    await tester.pumpAndSettle();
    
    // 2. HOME DASHBOARD
    // Wait for data to load
    await Future.delayed(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Verify Dashboard is visible
    expect(find.text('Good Morning,'), findsOneWidget);
    expect(find.text('Elias!'), findsOneWidget);

    // 3. NAVIGATE TO EXPENSES
    // Tap Expenses tab in BottomNavBar
    final expenseIcon = find.byIcon(Icons.receipt_long_rounded);
    await tester.tap(expenseIcon);
    await tester.pumpAndSettle();
    
    expect(find.text('Expenses'), findsWidgets);

    // 4. ADD NEW EXPENSE
    // Tap FAB or add button
    final fab = find.byType(FloatingActionButton);
    if (fab.evaluate().isNotEmpty) {
      await tester.tap(fab);
    } else {
      // Find the center Add button in curved nav dock
      await tester.tap(find.byIcon(Icons.add_rounded));
    }
    await tester.pumpAndSettle();

    // Verify we are in Submit Expense screen
    expect(find.text('Submit Expense'), findsWidgets);
    
    // Fill out the form
    await tester.enterText(find.byType(TextFormField).first, '1200'); // Base Cost
    await tester.pumpAndSettle();
    
    // Toggle Receipt Switch
    final switchFinder = find.byType(Switch).first;
    await tester.tap(switchFinder); // Turn off receipt
    await tester.pumpAndSettle();
    
    // Now enter justification note
    await tester.enterText(find.widgetWithText(TextFormField, 'Purpose / Non-Receipt Justification *'), 'Testing justification logic');
    await tester.pumpAndSettle();

    // Tap submit button
    await tester.tap(find.text('Submit Expense'));
    await tester.pumpAndSettle();

    // Verify it submitted successfully and popped
    expect(find.text('Submit Expense'), findsNothing);

    // 5. PROFILE / LOGOUT
    final profileIcon = find.byIcon(Icons.person_outline_rounded);
    if (profileIcon.evaluate().isNotEmpty) {
      await tester.tap(profileIcon);
      await tester.pumpAndSettle();
      
      // Tap Logout
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();
      
      // Confirm Logout
      await tester.tap(find.text('Logout').last);
      await tester.pumpAndSettle();
      
      // Should be back at Login Screen
      expect(find.text('Geospatial Works'), findsOneWidget);
    }
  });
}
