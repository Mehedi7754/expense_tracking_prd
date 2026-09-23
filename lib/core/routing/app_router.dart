import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_role.dart';
import '../../screens/admin/add_edit_user_screen.dart';
import '../../screens/admin/audit_log_screen.dart';
import '../../screens/admin/category_management_screen.dart';
import '../../screens/admin/client_analysis_screen.dart';
import '../../screens/admin/company_setup_screen.dart';
import '../../screens/admin/cost_estimator_screen.dart';
import '../../screens/admin/user_management_screen.dart';
import '../../screens/approvals/approvals_queue_screen.dart';
import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/auth/reset_password_screen.dart';
import '../../screens/expenses/edit_expense_screen.dart';
import '../../screens/expenses/expense_detail_screen.dart';
import '../../screens/expenses/my_expenses_screen.dart';
import '../../screens/expenses/receipt_compliance_screen.dart';
import '../../screens/expenses/submit_expense_screen.dart';
import '../../screens/main_shell_screen.dart';
import '../../screens/notifications/notification_detail_screen.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../screens/profile/employee_detail_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/profile/settings_screen.dart';
import '../../screens/projects/add_edit_project_screen.dart';
import '../../screens/projects/add_revenue_screen.dart';
import '../../screens/projects/project_detail_screen.dart';
import '../../screens/projects/project_team_screen.dart';
import '../../screens/projects/projects_list_screen.dart';
import '../../screens/reports/company_dashboard_screen.dart';
import '../../screens/reports/reports_screen.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/tasks/add_edit_task_screen.dart';
import '../../screens/tasks/task_detail_screen.dart';
import '../../state/auth_provider.dart';
import 'route_paths.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(
      authProvider,
      (_, __) => notifyListeners(),
    );
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authProvider);
    final loc = state.matchedLocation;
    final isAuthenticated = authState.isAuthenticated;
    final currentUser = authState.currentUser;
    final role = currentUser?.role ?? UserRole.projectMember;

    // Public auth routes
    final isAuthRoute = loc == RoutePaths.splash ||
        loc == RoutePaths.login ||
        loc == RoutePaths.register ||
        loc == RoutePaths.forgotPassword ||
        loc == RoutePaths.resetPassword;

    if (!isAuthenticated && !isAuthRoute) {
      return RoutePaths.login;
    }

    if (isAuthenticated && (loc == RoutePaths.login || loc == RoutePaths.register)) {
      return RoutePaths.home;
    }

    // Role-Based Guards
    if (isAuthenticated) {
      // Admin routes guard
      if (loc.startsWith('/admin') && role != UserRole.mainAdmin) {
        return RoutePaths.home;
      }

      // Finance / Admin company dashboard guard
      if (loc == RoutePaths.companyDashboard &&
          role != UserRole.finance &&
          role != UserRole.mainAdmin) {
        return RoutePaths.home;
      }

      // Add project guard (Manager and Admin only)
      if (loc == RoutePaths.addProject &&
          role != UserRole.projectManager &&
          role != UserRole.mainAdmin &&
          role != UserRole.finance) {
        return RoutePaths.home;
      }
    }

    return null;
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) => RouterNotifier(ref));

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: RoutePaths.splash,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RoutePaths.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: RoutePaths.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: RoutePaths.resetPassword,
        builder: (context, state) => const ResetPasswordScreen(),
      ),

      // Main Shell Screen (Adaptive Home + Role Bottom Nav Bar)
      GoRoute(
        path: RoutePaths.home,
        builder: (context, state) => const MainShellScreen(),
      ),

      // Expense Routes
      GoRoute(
        path: RoutePaths.submitExpense,
        builder: (context, state) => const SubmitExpenseScreen(),
      ),
      GoRoute(
        path: RoutePaths.myExpenses,
        builder: (context, state) => const MyExpensesScreen(),
      ),
      GoRoute(
        path: RoutePaths.receiptCompliance,
        builder: (context, state) => const ReceiptComplianceScreen(),
      ),
      GoRoute(
        path: RoutePaths.expenseDetailPattern,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ExpenseDetailScreen(expenseId: id);
        },
      ),
      GoRoute(
        path: RoutePaths.editExpensePattern,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return EditExpenseScreen(expenseId: id);
        },
      ),

      // Approvals Queue
      GoRoute(
        path: RoutePaths.approvalsQueue,
        builder: (context, state) => const ApprovalsQueueScreen(),
      ),

      // Projects
      GoRoute(
        path: RoutePaths.projects,
        builder: (context, state) => const ProjectsListScreen(),
      ),
      GoRoute(
        path: RoutePaths.addProject,
        builder: (context, state) => const AddEditProjectScreen(),
      ),
      GoRoute(
        path: RoutePaths.projectDetailPattern,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ProjectDetailScreen(projectId: id);
        },
      ),
      GoRoute(
        path: RoutePaths.editProjectPattern,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return AddEditProjectScreen(projectId: id);
        },
      ),
      GoRoute(
        path: RoutePaths.addRevenuePattern,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return AddRevenueScreen(projectId: id);
        },
      ),
      GoRoute(
        path: RoutePaths.projectTeamPattern,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ProjectTeamScreen(projectId: id);
        },
      ),

      // PFIS Intelligence Routes
      GoRoute(
        path: RoutePaths.clientAnalysis,
        builder: (context, state) => const ClientAnalysisScreen(),
      ),
      GoRoute(
        path: RoutePaths.costEstimator,
        builder: (context, state) => const CostEstimatorScreen(),
      ),

      // Tasks
      GoRoute(
        path: RoutePaths.addTask,
        builder: (context, state) {
          final projectId = state.uri.queryParameters['projectId'];
          final taskId = state.uri.queryParameters['taskId'];
          return AddEditTaskScreen(projectId: projectId, taskId: taskId);
        },
      ),
      GoRoute(
        path: RoutePaths.taskDetail,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return TaskDetailScreen(taskId: id);
        },
      ),

      // Reports & Company Dashboard
      GoRoute(
        path: RoutePaths.reports,
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: RoutePaths.companyDashboard,
        builder: (context, state) => const CompanyDashboardScreen(),
      ),

      // Administration
      GoRoute(
        path: RoutePaths.companySetup,
        builder: (context, state) => const CompanySetupScreen(),
      ),
      GoRoute(
        path: RoutePaths.userManagement,
        builder: (context, state) => const UserManagementScreen(),
      ),
      GoRoute(
        path: RoutePaths.addUser,
        builder: (context, state) => const AddEditUserScreen(),
      ),
      GoRoute(
        path: RoutePaths.editUser,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return AddEditUserScreen(userId: id);
        },
      ),
      GoRoute(
        path: RoutePaths.categoryManagement,
        builder: (context, state) => const CategoryManagementScreen(),
      ),
      GoRoute(
        path: RoutePaths.auditLog,
        builder: (context, state) => const AuditLogScreen(),
      ),

      // Notifications
      GoRoute(
        path: RoutePaths.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: RoutePaths.notificationDetail,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return NotificationDetailScreen(notificationId: id);
        },
      ),

      // Profile & Settings
      GoRoute(
        path: RoutePaths.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.employeeDetail,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return EmployeeDetailScreen(employeeId: id);
        },
      ),
    ],
  );
});
