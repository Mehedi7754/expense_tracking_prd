import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';

class AuthState {
  final UserModel? currentUser;
  final bool isAuthenticated;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.currentUser,
    this.isAuthenticated = false,
    this.isLoading = false,
    this.errorMessage,
  });

  AuthState copyWith({
    UserModel? currentUser,
    bool? isAuthenticated,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      currentUser: clearUser ? null : (currentUser ?? this.currentUser),
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// PRD Section 1 & 11 Demo Personas
class DemoUsers {
  static const UserModel mainAdmin = UserModel(
    id: 'usr_adm_01',
    name: 'Eleanor Vance',
    email: 'admin@pfis.com',
    role: UserRole.mainAdmin,
    department: 'Corporate Governance',
    designation: 'Managing Director / Admin',
    phone: '+880 1711-000001',
    assignedProjectIds: ['proj_01', 'proj_02', 'proj_03', 'proj_04', 'proj_05'],
  );

  static const UserModel projectManager = UserModel(
    id: 'usr_mgr_01',
    name: 'Sarah Jenkins',
    email: 'manager@pfis.com',
    role: UserRole.projectManager,
    department: 'Project Management & Field Ops',
    designation: 'Senior Project Manager',
    phone: '+880 1711-000002',
    assignedProjectIds: ['proj_01', 'proj_02'],
  );

  static const UserModel projectMember = UserModel(
    id: 'usr_emp_01',
    name: 'Fahim Ahmed',
    email: 'fahim@pfis.com',
    role: UserRole.projectMember,
    department: 'Field Survey & Operations',
    designation: 'Field Team Lead',
    phone: '+880 1812-345678',
    assignedProjectIds: ['proj_01'], // Strictly assigned to Project 01
  );

  static const UserModel finance = UserModel(
    id: 'usr_fin_01',
    name: 'David Chen',
    email: 'finance@pfis.com',
    role: UserRole.finance,
    department: 'Finance & Accounts',
    designation: 'Chief Financial Officer',
    phone: '+880 1711-000004',
    assignedProjectIds: ['proj_01', 'proj_02', 'proj_03', 'proj_04', 'proj_05'],
  );

  static const UserModel viewer = UserModel(
    id: 'usr_view_01',
    name: 'Rahim Chowdhury',
    email: 'viewer@pfis.com',
    role: UserRole.viewer,
    department: 'Client Advisory Committee',
    designation: 'External Independent Auditor',
    phone: '+880 1911-000005',
    assignedProjectIds: ['proj_02'], // Read-only assigned to Project 02
  );

  static List<UserModel> get all => [mainAdmin, projectManager, projectMember, finance, viewer];
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Default unauthenticated on boot (prevents auth bypass)
    return const AuthState();
  }

  // In-memory registry for users registered dynamically in the app
  static final List<UserModel> _registeredUsers = [];

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    required String department,
    String? designation,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    await Future.delayed(const Duration(milliseconds: 400));

    final normalized = email.trim().toLowerCase();

    // Check if account already exists
    final alreadyExists = DemoUsers.all.any((u) => u.email.toLowerCase() == normalized) ||
        _registeredUsers.any((u) => u.email.toLowerCase() == normalized);

    if (alreadyExists) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'An account with this email already exists.',
      );
      return false;
    }

    if (password.length < 3) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Password must be at least 3 characters.',
      );
      return false;
    }

    // Role-based assigned project access
    List<String> assignedProjects;
    switch (role) {
      case UserRole.mainAdmin:
      case UserRole.finance:
        assignedProjects = ['proj_01', 'proj_02', 'proj_03', 'proj_04', 'proj_05'];
        break;
      case UserRole.projectManager:
        assignedProjects = ['proj_01', 'proj_02'];
        break;
      case UserRole.projectMember:
        assignedProjects = ['proj_01'];
        break;
      case UserRole.viewer:
        assignedProjects = ['proj_02'];
        break;
    }

    final newUser = UserModel(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      email: email.trim(),
      role: role,
      department: department.trim().isEmpty ? 'Operations' : department.trim(),
      designation: (designation != null && designation.trim().isNotEmpty)
          ? designation.trim()
          : role.displayName,
      assignedProjectIds: assignedProjects,
    );

    _registeredUsers.add(newUser);

    state = state.copyWith(
      currentUser: newUser,
      isAuthenticated: true,
      isLoading: false,
      clearError: true,
    );
    return true;
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    await Future.delayed(const Duration(milliseconds: 400));

    final normalized = email.trim().toLowerCase();

    // Match against registered users first, then demo users
    UserModel? matched;
    try {
      matched = _registeredUsers.firstWhere((u) => u.email.toLowerCase() == normalized);
    } catch (_) {
      try {
        matched = DemoUsers.all.firstWhere((u) => u.email.toLowerCase() == normalized);
      } catch (_) {
        matched = null;
      }
    }

    if (password.length < 3) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Invalid password. Enter at least 3 characters.',
      );
      return false;
    }

    matched ??= UserModel(
      id: 'usr_custom',
      name: email.split('@').first,
      email: email,
      role: UserRole.projectMember,
      department: 'Field Staff',
      assignedProjectIds: ['proj_01'],
    );

    state = state.copyWith(
      currentUser: matched,
      isAuthenticated: true,
      isLoading: false,
      clearError: true,
    );
    return true;
  }

  void logout() {
    state = const AuthState(
      currentUser: null,
      isAuthenticated: false,
    );
  }

  void switchRole(UserRole role) {
    UserModel targetUser;
    switch (role) {
      case UserRole.mainAdmin:
        targetUser = DemoUsers.mainAdmin;
        break;
      case UserRole.projectManager:
        targetUser = DemoUsers.projectManager;
        break;
      case UserRole.projectMember:
        targetUser = DemoUsers.projectMember;
        break;
      case UserRole.finance:
        targetUser = DemoUsers.finance;
        break;
      case UserRole.viewer:
        targetUser = DemoUsers.viewer;
        break;
    }
    state = state.copyWith(currentUser: targetUser, isAuthenticated: true);
  }

  void updateProfileName(String newName) {
    if (state.currentUser != null) {
      state = state.copyWith(
        currentUser: state.currentUser!.copyWith(name: newName),
      );
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
