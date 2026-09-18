enum UserRole {
  employee,
  manager,
  finance,
  admin;

  String get displayName {
    switch (this) {
      case UserRole.employee:
        return 'Employee';
      case UserRole.manager:
        return 'Manager';
      case UserRole.finance:
        return 'Finance';
      case UserRole.admin:
        return 'Administrator';
    }
  }

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'manager':
        return UserRole.manager;
      case 'finance':
        return UserRole.finance;
      case 'admin':
      case 'administrator':
        return UserRole.admin;
      case 'employee':
      default:
        return UserRole.employee;
    }
  }
}
