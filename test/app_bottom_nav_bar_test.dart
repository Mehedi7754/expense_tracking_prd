import 'package:expense_tracking_prd/core/widgets/app_bottom_nav_bar.dart';
import 'package:expense_tracking_prd/models/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('admin dock puts the menu in the attendance slot', (
    tester,
  ) async {
    var menuTaps = 0;
    var pageTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppBottomNavBar(
            role: UserRole.mainAdmin,
            currentIndex: 2,
            onTap: (_) => pageTaps++,
            onMenuTap: () => menuTaps++,
          ),
        ),
      ),
    );

    expect(find.byTooltip('Menu'), findsOneWidget);
    expect(find.byTooltip('Attendance'), findsNothing);
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    expect(menuTaps, 1);
    expect(pageTaps, 0);
  });

  testWidgets('employee dock keeps attendance available in menu slot', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppBottomNavBar(
            role: UserRole.projectMember,
            currentIndex: 2,
            onTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.byTooltip('Menu'), findsOneWidget);
    expect(find.byTooltip('Attendance'), findsNothing);
    expect(find.byTooltip('Chat'), findsOneWidget);
  });
}
