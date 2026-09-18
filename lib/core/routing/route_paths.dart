class RoutePaths {
  RoutePaths._();

  static const String splash = '/';
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';

  // Shell / Tabs
  static const String home = '/home';
  static const String submitExpense = '/expenses/submit';
  static const String myExpenses = '/expenses/my-expenses';
  static const String approvalsQueue = '/approvals';
  static const String projects = '/projects';
  static const String companySetup = '/admin/company';
  static const String reports = '/reports';
  static const String notifications = '/notifications';
  static const String profile = '/profile';

  // Deep Link Sub-routes
  static const String expenseDetail = '/expenses/:id';
  static const String editExpense = '/expenses/:id/edit';
  static const String projectDetail = '/projects/:id';
  static const String addProject = '/projects/new';
  static const String editProject = '/projects/:id/edit';
  static const String addRevenue = '/projects/:id/revenue/new';
  static const String projectTeam = '/projects/:id/team';
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
}
