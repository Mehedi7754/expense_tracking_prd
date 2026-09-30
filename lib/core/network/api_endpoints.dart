import '../config/app_env.dart';

class ApiEndpoints {
  ApiEndpoints._();

  static String resolve(String relativePath) {
    final base = AppEnv.isInitialized ? AppEnv.apiBaseUrl : '';
    final path = relativePath.startsWith('/') ? relativePath : '/$relativePath';
    if (base.isEmpty) return path;
    return '$base$path';
  }

  // Authentication & Session Endpoints
  static String get login => resolve('/auth/login');
  static String get register => resolve('/auth/register');
  static String get me => resolve('/auth/me');
  static String get currentUser => resolve('/auth/me');
  static String get refresh => resolve('/auth/refresh');
  static String get refreshToken => resolve('/auth/refresh');
  static String get logout => resolve('/auth/logout');
  static String get updateProfile => resolve('/auth/profile');
  static String get forgotPassword => resolve('/auth/forgot-password');
  static String get resetPassword => resolve('/auth/reset-password');

  // Projects & Budget Endpoints
  static String get projects => resolve('/projects');
  static String projectById(String id) => resolve('/projects/$id');
  static String projectRevenues(String projectId) => resolve('/projects/$projectId/revenues');
  static String addProjectRevenue(String id) => resolve('/projects/$id/revenue');
  static String projectMembers(String projectId) => resolve('/projects/$projectId/members');
  static String closeProject(String projectId) => resolve('/projects/$projectId/close');
  static String get projectCostBreakdown => resolve('/projects/financials/cost-breakdown');

  // Expense Claims & Receipts Endpoints
  static String get expenses => resolve('/expenses');
  static String expenseById(String id) => resolve('/expenses/$id');
  static String expenseStatus(String id) => resolve('/expenses/$id/status');
  static String expenseComments(String expenseId) => resolve('/expenses/$expenseId/comments');
  static String submitJustification(String expenseId) => resolve('/expenses/$expenseId/justification');
  static String reviewJustification(String expenseId) => resolve('/expenses/$expenseId/justification/review');
  static String get submitExpense => resolve('/expenses/submit');
  static String updateExpense(String id) => resolve('/expenses/$id');
  static String deleteExpense(String id) => resolve('/expenses/$id');
  static String approveExpense(String id) => resolve('/expenses/$id/approve');
  static String rejectExpense(String id) => resolve('/expenses/$id/reject');
  static String uploadReceipt(String id) => resolve('/expenses/$id/receipt');
  static String get receiptCompliance => resolve('/expenses/compliance');

  // Categories & Policy Caps Endpoints
  static String get categories => resolve('/categories');
  static String categoryById(String id) => resolve('/categories/$id');

  // Clients & Cost Estimation Endpoints
  static String get clients => resolve('/clients');
  static String clientById(String id) => resolve('/clients/$id');
  static String clientAnalysis(String id) => resolve('/clients/$id/analysis');
  static String get costEstimator => resolve('/admin/cost-estimator/historical');
  static String get benchmarks => resolve('/estimator/benchmarks');

  // Tasks & Allocations Endpoints
  static String get tasks => resolve('/tasks');
  static String taskById(String id) => resolve('/tasks/$id');

  // User Management & RBAC Endpoints
  static String get users => resolve('/users');
  static String userById(String id) => resolve('/users/$id');

  // Audit Trail & Notifications Endpoints
  static String get auditLogs => resolve('/audit-logs');
  static String get notifications => resolve('/notifications');
  static String notificationById(String id) => resolve('/notifications/$id');
  static String markNotificationRead(String id) => resolve('/notifications/$id/read');

  // Reports & Financial Analytics
  static String get financialSummaryReport => resolve('/reports/financial-summary');
  static String get receiptComplianceReport => resolve('/reports/receipt-compliance');
  static String get reportsSummary => resolve('/reports/summary');
  static String get exportReport => resolve('/reports/export');
}
