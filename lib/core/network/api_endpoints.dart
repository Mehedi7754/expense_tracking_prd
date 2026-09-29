class ApiEndpoints {
  ApiEndpoints._();

  // Authentication
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String me = '/auth/me';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String updateProfile = '/auth/profile';

  // Projects
  static const String projects = '/projects';
  static String projectById(String id) => '/projects/$id';
  static String projectRevenues(String projectId) => '/projects/$projectId/revenues';
  static String projectMembers(String projectId) => '/projects/$projectId/members';
  static String closeProject(String projectId) => '/projects/$projectId/close';

  // Expenses
  static const String expenses = '/expenses';
  static String expenseById(String id) => '/expenses/$id';
  static String expenseStatus(String id) => '/expenses/$id/status';
  static String expenseComments(String expenseId) => '/expenses/$expenseId/comments';
  static String submitJustification(String expenseId) => '/expenses/$expenseId/justification';
  static String reviewJustification(String expenseId) => '/expenses/$expenseId/justification/review';

  // Categories
  static const String categories = '/categories';
  static String categoryById(String id) => '/categories/$id';

  // Clients
  static const String clients = '/clients';
  static String clientById(String id) => '/clients/$id';

  // Tasks
  static const String tasks = '/tasks';
  static String taskById(String id) => '/tasks/$id';

  // Audit Logs
  static const String auditLogs = '/audit-logs';

  // Notifications
  static const String notifications = '/notifications';
  static String markNotificationRead(String id) => '/notifications/$id/read';

  // Reports & Analytics
  static const String financialSummaryReport = '/reports/financial-summary';
  static const String receiptComplianceReport = '/reports/receipt-compliance';

  // Estimator & Benchmarks
  static const String benchmarks = '/estimator/benchmarks';
}
