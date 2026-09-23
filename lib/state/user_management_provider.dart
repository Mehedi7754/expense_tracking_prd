import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';

class UserManagementNotifier extends Notifier<List<UserModel>> {
  static final List<UserModel> _initialUsers = [
    const UserModel(
      id: 'usr_adm_01',
      name: 'Eleanor Vance',
      email: 'admin@pfis.com',
      role: UserRole.mainAdmin,
      department: 'Corporate Governance',
      designation: 'Managing Director / Admin',
      isActive: true,
      assignedProjectIds: ['proj_01', 'proj_02', 'proj_03', 'proj_04', 'proj_05'],
    ),
    const UserModel(
      id: 'usr_mgr_01',
      name: 'Sarah Jenkins',
      email: 'manager@pfis.com',
      role: UserRole.projectManager,
      department: 'Project Management & Field Ops',
      designation: 'Senior Project Manager',
      isActive: true,
      assignedProjectIds: ['proj_01', 'proj_02'],
    ),
    const UserModel(
      id: 'usr_emp_01',
      name: 'Fahim Ahmed',
      email: 'fahim@pfis.com',
      role: UserRole.projectMember,
      department: 'Field Survey & Operations',
      designation: 'Field Team Lead',
      isActive: true,
      assignedProjectIds: ['proj_01'],
    ),
    const UserModel(
      id: 'usr_fin_01',
      name: 'David Chen',
      email: 'finance@pfis.com',
      role: UserRole.finance,
      department: 'Finance & Accounts',
      designation: 'Chief Financial Officer',
      isActive: true,
      assignedProjectIds: ['proj_01', 'proj_02', 'proj_03', 'proj_04', 'proj_05'],
    ),
    const UserModel(
      id: 'usr_view_01',
      name: 'Rahim Chowdhury',
      email: 'viewer@pfis.com',
      role: UserRole.viewer,
      department: 'Client Advisory Committee',
      designation: 'External Independent Auditor',
      isActive: true,
      assignedProjectIds: ['proj_02'],
    ),
    const UserModel(
      id: 'usr_emp_03',
      name: 'Karim Ullah',
      email: 'karim@pfis.com',
      role: UserRole.projectMember,
      department: 'Water & Sanitation Team',
      designation: 'Field Enumeration Specialist',
      isActive: true,
      assignedProjectIds: ['proj_03'],
    ),
  ];

  @override
  List<UserModel> build() => _initialUsers;

  void addUser({
    required String name,
    required String email,
    required UserRole role,
    required String department,
    String? designation,
    List<String> assignedProjectIds = const [],
  }) {
    final newUser = UserModel(
      id: 'usr_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      email: email,
      role: role,
      department: department,
      designation: designation,
      isActive: true,
      assignedProjectIds: assignedProjectIds,
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
