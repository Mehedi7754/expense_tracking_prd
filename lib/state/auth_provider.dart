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
    // Role switcher helper for integration testing and runtime role preview
    final targetUser = UserModel(
      id: 'usr_${role.name}',
      name: '${role.displayName} User',
      email: '${role.name}@pfis.com',
      role: role,
      department: 'Corporate',
      designation: role.displayName,
      assignedProjectIds: const [],
    );
    state = state.copyWith(
      currentUser: targetUser,
      isAuthenticated: true,
      clearError: true,
    );
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

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
