import 'package:expense_tracking_prd/core/widgets/quick_access_dock_menu.dart';
import 'package:expense_tracking_prd/models/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('admin drawer exposes task, assignment and payroll routes', (
    tester,
  ) async {
    final destinations = <String>[];
    var closes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              QuickAccessDockMenu(
                role: UserRole.mainAdmin,
                expanded: true,
                onClose: () => closes++,
                onNavigate: destinations.add,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('More'), findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Assign task'), findsOneWidget);
    expect(find.text('Payroll'), findsOneWidget);
    await tester.tap(find.text('Assign task'));
    await tester.pumpAndSettle();
    expect(destinations, ['/tasks/new']);
    expect(closes, 1);
  });

  testWidgets('employee drawer offers personal actions without assignment', (
    tester,
  ) async {
    final destinations = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              QuickAccessDockMenu(
                role: UserRole.projectMember,
                expanded: true,
                onClose: () {},
                onNavigate: destinations.add,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('My Tasks'), findsOneWidget);
    expect(find.text('My Pay'), findsOneWidget);
    expect(find.text('My Attendance'), findsOneWidget);
    expect(find.text('Assign task'), findsNothing);
    await tester.tap(find.text('My Tasks'));
    await tester.pumpAndSettle();
    expect(destinations, ['/tasks']);
  });
}
