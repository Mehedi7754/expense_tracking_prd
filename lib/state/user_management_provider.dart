import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';

class UserManagementNotifier extends Notifier<List<UserModel>> {
  static final List<UserModel> _initialUsers = [
    const UserModel(
      id: 'usr_emp_01',
      name: 'Alex Morgan',
      email: 'alex.morgan@company.com',
      role: UserRole.employee,
      department: 'Engineering',
      isActive: true,
    ),
    const UserModel(
      id: 'usr_mgr_01',
      name: 'Sarah Jenkins',
      email: 'sarah.jenkins@company.com',
      role: UserRole.manager,
      department: 'Product & Operations',
      isActive: true,
    ),
    const UserModel(
      id: 'usr_fin_01',
      name: 'David Chen',
      email: 'david.chen@company.com',
      role: UserRole.finance,
      department: 'FP&A Finance',
      isActive: true,
    ),
    const UserModel(
      id: 'usr_adm_01',
      name: 'Eleanor Vance',
      email: 'eleanor.vance@company.com',
      role: UserRole.admin,
      department: 'Corporate Governance',
      isActive: true,
    ),
    const UserModel(
      id: 'usr_emp_02',
      name: 'Jordan Taylor',
      email: 'jordan.taylor@company.com',
      role: UserRole.employee,
      department: 'DevOps & SRE',
      isActive: true,
    ),
    const UserModel(
      id: 'usr_emp_03',
      name: 'Maya Patel',
      email: 'maya.patel@company.com',
      role: UserRole.employee,
      department: 'Product Design',
      isActive: true,
    ),
    const UserModel(
      id: 'usr_emp_04',
      name: 'Lucas Wright',
      email: 'lucas.wright@company.com',
      role: UserRole.employee,
      department: 'Sales & Growth',
      isActive: false,
    ),
  ];

  @override
  List<UserModel> build() => _initialUsers;

  void addUser({
    required String name,
    required String email,
    required UserRole role,
    required String department,
  }) {
    final newUser = UserModel(
      id: 'usr_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      email: email,
      role: role,
      department: department,
      isActive: true,
    );
    state = [...state, newUser];
  }

  void updateUser(UserModel updated) {
    state = [
      for (final u in state)
        if (u.id == updated.id) updated else u,
    ];
  }

  void changeRole(String userId, UserRole newRole) {
    state = [
      for (final u in state)
        if (u.id == userId) u.copyWith(role: newRole) else u,
    ];
  }

  void toggleActive(String userId) {
    state = [
      for (final u in state)
        if (u.id == userId) u.copyWith(isActive: !u.isActive) else u,
    ];
  }
}

final userManagementProvider =
    NotifierProvider<UserManagementNotifier, List<UserModel>>(UserManagementNotifier.new);
