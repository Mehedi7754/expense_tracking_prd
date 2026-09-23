enum UserRole {
  mainAdmin,
  projectManager,
  projectMember,
  finance,
  viewer;

  String get displayName {
    switch (this) {
      case UserRole.mainAdmin:
        return 'Main Admin';
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
  bool get canCreateProject => this == UserRole.mainAdmin || this == UserRole.finance;
  bool get canManageUsers => this == UserRole.mainAdmin;
  bool get canApproveExpenses =>
      this == UserRole.mainAdmin || this == UserRole.projectManager || this == UserRole.finance;
  bool get canApproveJustifications =>
      this == UserRole.mainAdmin || this == UserRole.finance;
  bool get canEnterExpenses =>
      this == UserRole.projectMember ||
      this == UserRole.projectManager ||
      this == UserRole.mainAdmin;
  bool get isReadOnly => this == UserRole.viewer;

  static UserRole fromString(String role) {
    switch (role.toLowerCase().replaceAll(' ', '').replaceAll('/', '').replaceAll('_', '')) {
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
