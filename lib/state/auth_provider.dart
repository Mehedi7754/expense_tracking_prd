import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_exceptions.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import '../repositories/auth_repository.dart';

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

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Default clean unauthenticated state on startup
    return const AuthState();
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    required String department,
    String? designation,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.register(
        name: name,
        email: email,
        password: password,
        role: role.name,
        department: department,
        designation: designation,
      );

      state = state.copyWith(
        currentUser: user,
        isAuthenticated: true,
        isLoading: false,
        clearError: true,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Registration error: $e',
      );
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.login(email, password);

      state = state.copyWith(
        currentUser: user,
        isAuthenticated: true,
        isLoading: false,
        clearError: true,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Login error: $e',
      );
      return false;
    }
  }

  Future<void> logout() async {
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.logout();
    } catch (_) {
      // Ignore network errors on logout
    }
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
    state = state.copyWith(currentUser: targetUser, isAuthenticated: true, clearError: true);
  }

  void setUser(UserModel user) {
    state = state.copyWith(
      currentUser: user,
      isAuthenticated: true,
      clearError: true,
    );
  }

  void updateProfileName(String newName) {
    if (state.currentUser != null) {
      state = state.copyWith(
        currentUser: state.currentUser!.copyWith(name: newName),
      );
    }
  }

  void updateAvatarUrl(String? url) {
    if (state.currentUser != null) {
      state = state.copyWith(
        currentUser: state.currentUser!.copyWith(avatarUrl: url),
      );
    }
  }
}

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
    assignedProjectIds: ['proj_01'],
  );

  static const UserModel finance = UserModel(
    id: 'usr_fin_01',
    name: 'David Chen',
    email: 'finance@pfis.com',
    role: UserRole.finance,
    department: 'Finance & Compliance',
    designation: 'Chief Financial Officer',
    phone: '+880 1711-000004',
    assignedProjectIds: ['proj_01', 'proj_02', 'proj_03', 'proj_04', 'proj_05'],
  );

  static const UserModel viewer = UserModel(
    id: 'usr_view_01',
    name: 'Rahim Chowdhury',
    email: 'viewer@pfis.com',
    role: UserRole.viewer,
    department: 'External Audit & Advisory',
    designation: 'External Financial Auditor',
    phone: '+880 1711-000005',
    assignedProjectIds: ['proj_01', 'proj_02'],
  );

  static const List<UserModel> all = [
    mainAdmin,
    projectManager,
    projectMember,
    finance,
    viewer,
  ];
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

