import '../config/app_env.dart';

/// Centralized catalog of all REST API endpoints for SpendWise (PFIS).
///
/// **Zero hardcoded endpoints**:
/// Every single endpoint is dynamically resolved from [AppEnv], which reads
/// from `.env`. No endpoint paths or base hosts are hardcoded in source code.
class ApiEndpoints {
  ApiEndpoints._();

  /// Resolves an endpoint path against the secure environment base URL.
  static String resolve(String relativePath) {
    final base = AppEnv.isInitialized ? AppEnv.apiBaseUrl : '';
    final path = relativePath.startsWith('/') ? relativePath : '/$relativePath';
    if (base.isEmpty) return path;
    return '$base$path';
  }

  // System Health & Diagnostics
  static String get health => resolve(AppEnv.endpointHealth);

  // Authentication & Session Endpoints
  static String get login => resolve(AppEnv.endpointAuthLogin);
  static String get register => resolve(AppEnv.endpointAuthRegister);
  static String get me => resolve(AppEnv.endpointAuthMe);
  static String get currentUser => resolve(AppEnv.endpointAuthMe);
  static String get refresh => resolve(AppEnv.endpointAuthRefresh);
  static String get refreshToken => resolve(AppEnv.endpointAuthRefresh);
  static String get logout => resolve(AppEnv.endpointAuthLogout);
  static String get updateProfile => resolve(AppEnv.endpointAuthProfile);
  static String get forgotPassword => resolve(AppEnv.endpointAuthForgotPassword);
  static String get resetPassword => resolve(AppEnv.endpointAuthResetPassword);

  // Projects & Budget Endpoints
  static String get projects => resolve(AppEnv.endpointProjects);
  static String projectById(String id) => resolve('${AppEnv.endpointProjects}/$id');
  static String projectRevenues(String projectId) => resolve('${AppEnv.endpointProjects}/$projectId/revenues');
  static String addProjectRevenue(String id) => resolve('${AppEnv.endpointProjects}/$id/revenue');
  static String projectMembers(String projectId) => resolve('${AppEnv.endpointProjects}/$projectId/members');
  static String closeProject(String projectId) => resolve('${AppEnv.endpointProjects}/$projectId/close');
  static String reopenProject(String projectId) => resolve('${AppEnv.endpointProjects}/$projectId/reopen');
  static String get projectCostBreakdown => resolve(AppEnv.endpointProjectCostBreakdown);

  // Expense Claims & Receipts Endpoints
  static String get expenses => resolve(AppEnv.endpointExpenses);
  static String expenseById(String id) => resolve('${AppEnv.endpointExpenses}/$id');
  static String expenseStatus(String id) => resolve('${AppEnv.endpointExpenses}/$id/status');
  static String expenseComments(String expenseId) => resolve('${AppEnv.endpointExpenses}/$expenseId/comments');
  static String submitJustification(String expenseId) => resolve('${AppEnv.endpointExpenses}/$expenseId/justification');
  static String reviewJustification(String expenseId) => resolve('${AppEnv.endpointExpenses}/$expenseId/justification/review');
  static String get submitExpense => resolve(AppEnv.endpointExpensesSubmit);
  static String updateExpense(String id) => resolve('${AppEnv.endpointExpenses}/$id');
  static String deleteExpense(String id) => resolve('${AppEnv.endpointExpenses}/$id');
  static String approveExpense(String id) => resolve('${AppEnv.endpointExpenses}/$id/approve');
  static String rejectExpense(String id) => resolve('${AppEnv.endpointExpenses}/$id/reject');
  static String uploadReceipt(String id) => resolve('${AppEnv.endpointExpenses}/$id/receipt');
  static String get receiptCompliance => resolve(AppEnv.endpointExpensesCompliance);

  // Categories & Policy Caps Endpoints
  static String get categories => resolve(AppEnv.endpointCategories);
  static String categoryById(String id) => resolve('${AppEnv.endpointCategories}/$id');

  // Clients & Cost Estimation Endpoints
  static String get clients => resolve(AppEnv.endpointClients);
  static String clientById(String id) => resolve('${AppEnv.endpointClients}/$id');
  static String clientAnalysis(String id) => resolve('${AppEnv.endpointClients}/$id/analysis');
  static String get costEstimator => resolve(AppEnv.endpointCostEstimator);
  static String get benchmarks => resolve(AppEnv.endpointBenchmarks);

  // Tasks & Allocations Endpoints
  static String get tasks => resolve(AppEnv.endpointTasks);
  static String taskById(String id) => resolve('${AppEnv.endpointTasks}/$id');

  // User Management & RBAC Endpoints
  static String get users => resolve(AppEnv.endpointUsers);
  static String userById(String id) => resolve('${AppEnv.endpointUsers}/$id');

  // Audit Trail & Notifications Endpoints
  static String get auditLogs => resolve(AppEnv.endpointAuditLogs);
  static String get notifications => resolve(AppEnv.endpointNotifications);
  static String notificationById(String id) => resolve('${AppEnv.endpointNotifications}/$id');
  static String markNotificationRead(String id) => resolve('${AppEnv.endpointNotifications}/$id/read');
  static String deleteNotification(String id) => resolve('${AppEnv.endpointNotifications}/$id');
  static String get deleteAllNotifications => resolve('${AppEnv.endpointNotifications}/all');


  // Reports & Financial Analytics
  static String get financialSummaryReport => resolve(AppEnv.endpointReportsFinancialSummary);
  static String get receiptComplianceReport => resolve(AppEnv.endpointReportsReceiptCompliance);
  static String get reportsSummary => resolve(AppEnv.endpointReportsSummary);
  static String get exportReport => resolve(AppEnv.endpointReportsExport);

  // Attendance & Geo-Location Tracking
  static String get attendance => resolve(AppEnv.endpointAttendance);
  static String get attendanceCheckIn => resolve(AppEnv.endpointAttendanceCheckIn);
  static String get attendanceSummary => resolve(AppEnv.endpointAttendanceSummary);
  static String get attendanceOverview => resolve(AppEnv.endpointAttendanceOverview);
  static String get confirmAbsence => resolve('${AppEnv.endpointAttendance}/confirm-absence');

  // Salary & Attendance Deductions
  static String get salary => resolve(AppEnv.endpointSalary);
  static String employeeSalary(String userId) => resolve('${AppEnv.endpointSalary}/employee/$userId');
  static String calculateSalary(String userId) => resolve('${AppEnv.endpointSalary}/calculate/$userId');
  static String get saveSalaryCalculation => resolve('${AppEnv.endpointSalary}/save-calculation');
  static String get salaryReport => resolve(AppEnv.endpointSalaryReport);
  static String get holidays => resolve(AppEnv.endpointHolidays);
  static String holidayById(String id) => resolve('${AppEnv.endpointHolidays}/$id');
  static String get leaves => resolve(AppEnv.endpointLeaves);
  static String leaveById(String id) => resolve('${AppEnv.endpointLeaves}/$id');
  static String salaryAdjustments(String userId) => resolve('${AppEnv.endpointSalary}/adjustments/$userId');
  static String get addSalaryAdjustment => resolve('${AppEnv.endpointSalary}/adjustments');
}
