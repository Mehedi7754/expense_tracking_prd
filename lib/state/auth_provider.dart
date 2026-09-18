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

// Pre-defined enterprise demo personas for testing
class DemoUsers {
  static const UserModel employee = UserModel(
    id: 'usr_emp_01',
    name: 'Alex Morgan',
    email: 'alex.morgan@company.com',
    role: UserRole.employee,
    department: 'Engineering',
  );

  static const UserModel manager = UserModel(
    id: 'usr_mgr_01',
    name: 'Sarah Jenkins',
    email: 'sarah.jenkins@company.com',
    role: UserRole.manager,
    department: 'Product & Operations',
  );

  static const UserModel finance = UserModel(
    id: 'usr_fin_01',
    name: 'David Chen',
    email: 'david.chen@company.com',
    role: UserRole.finance,
    department: 'Financial Planning & Analysis',
  );

  static const UserModel admin = UserModel(
    id: 'usr_adm_01',
    name: 'Eleanor Vance',
    email: 'eleanor.vance@company.com',
    role: UserRole.admin,
    department: 'Corporate Governance',
  );

  static List<UserModel> get all => [employee, manager, finance, admin];
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    return const AuthState(
      currentUser: null,
      isAuthenticated: false,
    );
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    await Future.delayed(const Duration(milliseconds: 600));

    final normalized = email.trim().toLowerCase();
    final matched = DemoUsers.all.firstWhere(
      (u) => u.email.toLowerCase() == normalized,
      orElse: () => UserModel(
        id: 'usr_custom',
        name: email.split('@').first,
        email: email,
        role: UserRole.employee,
        department: 'General Staff',
      ),
    );

    if (password.length < 4) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Invalid password. Must be at least 4 characters.',
      );
      return false;
    }

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
      case UserRole.employee:
        targetUser = DemoUsers.employee;
        break;
      case UserRole.manager:
        targetUser = DemoUsers.manager;
        break;
      case UserRole.finance:
        targetUser = DemoUsers.finance;
        break;
      case UserRole.admin:
        targetUser = DemoUsers.admin;
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
