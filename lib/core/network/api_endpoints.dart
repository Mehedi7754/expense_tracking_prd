import '../config/app_env.dart';

/// Centralized catalog of all REST API endpoints for SpendWise (PFIS).
///
/// Every endpoint is resolved dynamically against the secure [AppEnv.apiBaseUrl]
/// loaded from `.env`. No URLs or hosts are hardcoded.
class ApiEndpoints {
  ApiEndpoints._();

  /// Resolves a relative path to a full URL using the secure environment base URL.
  static String resolve(String relativePath) {
    final base = AppEnv.apiBaseUrl;
    final path = relativePath.startsWith('/') ? relativePath : '/$relativePath';
    return '$base$path';
  }

  // ==========================================
  // Authentication & Session Endpoints
  // ==========================================
  static String get login => resolve('/auth/login');
  static String get register => resolve('/auth/register');
  static String get logout => resolve('/auth/logout');
  static String get refreshToken => resolve('/auth/refresh');
  static String get forgotPassword => resolve('/auth/forgot-password');
  static String get resetPassword => resolve('/auth/reset-password');
  static String get currentUser => resolve('/auth/me');

  // ==========================================
  // Expense Claims & Receipts Endpoints
  // ==========================================
  static String get expenses => resolve('/expenses');
  static String expenseById(String id) => resolve('/expenses/$id');
  static String get submitExpense => resolve('/expenses/submit');
  static String updateExpense(String id) => resolve('/expenses/$id');
  static String deleteExpense(String id) => resolve('/expenses/$id');
  static String approveExpense(String id) => resolve('/expenses/$id/approve');
  static String rejectExpense(String id) => resolve('/expenses/$id/reject');
  static String uploadReceipt(String id) => resolve('/expenses/$id/receipt');
  static String get receiptCompliance => resolve('/expenses/compliance');

  // ==========================================
  // Projects & Budget Endpoints
  // ==========================================
  static String get projects => resolve('/projects');
  static String projectById(String id) => resolve('/projects/$id');
  static String addProjectRevenue(String id) => resolve('/projects/$id/revenue');
  static String get projectCostBreakdown => resolve('/projects/financials/cost-breakdown');

  // ==========================================
  // Tasks & Allocations Endpoints
  // ==========================================
  static String get tasks => resolve('/tasks');
  static String taskById(String id) => resolve('/tasks/$id');

  // ==========================================
  // Categories & Policy Caps Endpoints
  // ==========================================
  static String get categories => resolve('/categories');
  static String categoryById(String id) => resolve('/categories/$id');

  // ==========================================
  // Clients & Cost Estimation Endpoints
  // ==========================================
  static String get clients => resolve('/clients');
  static String clientAnalysis(String id) => resolve('/clients/$id/analysis');
  static String get costEstimator => resolve('/admin/cost-estimator/historical');

  // ==========================================
  // User Management & RBAC Endpoints
  // ==========================================
  static String get users => resolve('/users');
  static String userById(String id) => resolve('/users/$id');

  // ==========================================
  // Audit Trail & Notifications Endpoints
  // ==========================================
  static String get auditLogs => resolve('/audit-logs');
  static String get notifications => resolve('/notifications');
  static String notificationById(String id) => resolve('/notifications/$id');
  static String markNotificationRead(String id) => resolve('/notifications/$id/read');

  // ==========================================
  // Reports & Financial Analytics
  // ==========================================
  static String get reportsSummary => resolve('/reports/summary');
  static String get exportReport => resolve('/reports/export');
}
