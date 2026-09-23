import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/routing/route_paths.dart';
import '../core/widgets/app_bottom_nav_bar.dart';
import '../models/expense_model.dart';
import '../models/user_role.dart';
import '../state/auth_provider.dart';
import '../state/expense_provider.dart';
import '../state/notification_provider.dart';
import 'approvals/approvals_queue_screen.dart';
import 'expenses/my_expenses_screen.dart';
import 'expenses/receipt_compliance_screen.dart';
import 'home/home_dashboard_screen.dart';
import 'profile/profile_screen.dart';
import 'projects/projects_list_screen.dart';
import 'reports/reports_screen.dart';

class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  int _currentIndex = 0;
  UserRole? _lastRole;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.currentUser;
    final role = user?.role ?? UserRole.projectMember;

    // Reset tab to 0 if the role was switched
    if (_lastRole != role) {
      _lastRole = role;
      _currentIndex = 0;
    }

    final expenses = ref.watch(expenseProvider);
    final pendingCount = expenses.where((e) => e.status == ExpenseStatus.pending).length;

    final notifications = ref.watch(notificationProvider);
    final unreadNotifsCount = notifications.where((n) {
      if (user == null) return false;
      return (n.userId == user.id || n.userId.isEmpty) && !n.isRead;
    }).length;

    final List<Widget> screens = _getScreensForRole(role);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex.clamp(0, screens.length - 1),
        children: screens,
      ),
      bottomNavigationBar: AppBottomNavBar(
        role: role,
        currentIndex: _currentIndex,
        pendingApprovalsCount: pendingCount,
        unreadNotificationsCount: unreadNotifsCount,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        onAddTap: () {
          // Centered Floating '+' Button action
          context.push(RoutePaths.submitExpense);
        },
      ),
    );
  }

  List<Widget> _getScreensForRole(UserRole role) {
    switch (role) {
      case UserRole.projectMember:
        return const [
          HomeDashboardScreen(),
          MyExpensesScreen(),
          ReceiptComplianceScreen(),
          ProfileScreen(),
        ];

      case UserRole.projectManager:
      case UserRole.finance:
      case UserRole.mainAdmin:
        return const [
          HomeDashboardScreen(),
          ProjectsListScreen(),
          ApprovalsQueueScreen(),
          ProfileScreen(),
        ];

      case UserRole.viewer:
        return const [
          HomeDashboardScreen(),
          ProjectsListScreen(),
          ReportsScreen(),
          ProfileScreen(),
        ];
    }
  }
}
