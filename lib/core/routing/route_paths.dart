class RoutePaths {
  RoutePaths._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';

  // Shell / Tabs
  static const String home = '/home';
  static const String submitExpense = '/expenses/submit';
  static const String myExpenses = '/expenses/my-expenses';
  static const String approvalsQueue = '/approvals';
  static const String projects = '/projects';
  static const String projectsList = '/projects';
  static const String companySetup = '/admin/company';
  static const String reports = '/reports';
  static const String notifications = '/notifications';
  static const String profile = '/profile';

  // PFIS Specialized Routes
  static const String receiptCompliance = '/receipt-compliance';
  static const String clientAnalysis = '/admin/client-analysis';
  static const String costEstimator = '/admin/cost-estimator';

  // Deep Link Sub-routes
  static const String expenseDetailPattern = '/expenses/:id';
  static const String editExpensePattern = '/expenses/:id/edit';
  static const String projectDetailPattern = '/projects/:id';
  static const String addProject = '/projects/new';
  static const String editProjectPattern = '/projects/:id/edit';
  static const String addRevenuePattern = '/projects/:id/revenue/new';
  static const String projectTeamPattern = '/projects/:id/team';
  static const String taskDetail = '/tasks/:id';
  static const String addTask = '/tasks/new';
  static const String companyDashboard = '/company-dashboard';
  static const String userManagement = '/admin/users';
  static const String addUser = '/admin/users/new';
  static const String editUser = '/admin/users/:id/edit';
  static const String categoryManagement = '/admin/categories';
  static const String auditLog = '/admin/audit-log';
  static const String notificationDetail = '/notifications/:id';
  static const String settings = '/settings';
  static const String employeeDetail = '/employees/:id';

  static String projectDetail(String id) => '/projects/$id';
  static String editProject(String id) => '/projects/$id/edit';
  static String addRevenue(String id) => '/projects/$id/revenue/new';
  static String projectTeam(String id) => '/projects/$id/team';
  static String expenseDetail(String id) => '/expenses/$id';
  static String editExpense(String id) => '/expenses/$id/edit';
}
