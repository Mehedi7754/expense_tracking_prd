enum UserRole {
  mainAdmin,
  projectManager,
  projectMember,
  finance,
  viewer;

  /// The only active roles in the app per requirement: Super Admin, Project Manager, Project Member
  static const List<UserRole> activeRoles = [
    UserRole.mainAdmin,
    UserRole.projectManager,
    UserRole.projectMember,
  ];

  /// Roles permitted during registration: Project Member and Project Manager only
  static const List<UserRole> registrationRoles = [
    UserRole.projectMember,
    UserRole.projectManager,
  ];

  String get displayName {
    switch (this) {
      case UserRole.mainAdmin:
        return 'Super Admin';
      case UserRole.projectManager:
        return 'Project Manager';
      case UserRole.projectMember:
        return 'Project Member';
      case UserRole.finance:
        return 'Finance / Accounts';
      case UserRole.viewer:
        return 'Viewer (Read-Only)';
    }
  }

  bool get canViewAllProjects => this == UserRole.mainAdmin || this == UserRole.finance;
  /// Only Manager (projectManager) and Employee (projectMember) are required to check in.
  /// Super Admin (mainAdmin), Finance, and Viewer do NOT check in.
  bool get requiresAttendanceCheckIn =>
      this == UserRole.projectManager || this == UserRole.projectMember;
  bool get canManageAttendanceAndSalary =>
      this == UserRole.mainAdmin ||
      this == UserRole.projectManager ||
      this == UserRole.finance;
  bool get canCreateProject =>
      this == UserRole.mainAdmin || this == UserRole.projectManager;
  bool get canUpdateProjectProgress =>
      this == UserRole.mainAdmin || this == UserRole.projectManager;
  bool get canManageUsers =>
      this == UserRole.mainAdmin || this == UserRole.projectManager;
  bool get canApproveMembers =>
      this == UserRole.mainAdmin ||
      this == UserRole.projectManager;
  bool get canApproveExpenses =>
      this == UserRole.mainAdmin || this == UserRole.projectManager;
  bool get canApproveJustifications =>
      this == UserRole.mainAdmin || this == UserRole.projectManager;
  bool get canEnterExpenses =>
      this == UserRole.projectMember ||
      this == UserRole.projectManager ||
      this == UserRole.mainAdmin;
  bool get isReadOnly => this == UserRole.viewer;

  static UserRole fromString(String role) {
    switch (role.toLowerCase().replaceAll(' ', '').replaceAll('/', '').replaceAll('_', '')) {
      case 'superadmin':
      case 'mainadmin':
      case 'admin':
      case 'administrator':
        return UserRole.mainAdmin;
      case 'projectadmin':
      case 'projectmanager':
      case 'manager':
        return UserRole.projectManager;
      case 'finance':
      case 'accounts':
      case 'accountsfinance':
        return UserRole.finance;
      case 'viewer':
      case 'readonly':
        return UserRole.viewer;
      case 'projectmember':
      case 'member':
      case 'employee':
      default:
        return UserRole.projectMember;
    }
  }
}
