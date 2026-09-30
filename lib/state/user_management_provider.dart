import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';

class UserManagementNotifier extends Notifier<List<UserModel>> {
  @override
  List<UserModel> build() {
    // Default clean empty state on startup (no hardcoded demo users)
    return const [];
  }

  Future<void> fetchUsers() async {
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get('/users');
      if (response is List) {
        state = response
            .whereType<Map<String, dynamic>>()
            .map(UserModel.fromJson)
            .toList();
      } else if (response is Map<String, dynamic> && response['data'] is List) {
        state = (response['data'] as List)
            .whereType<Map<String, dynamic>>()
            .map(UserModel.fromJson)
            .toList();
      }
    } catch (_) {
      // Keep existing state on network disconnect
    }
  }

  void setUsers(List<UserModel> users) {
    state = users;
  }

  Future<void> addUser({
    required String name,
    required String email,
    required UserRole role,
    required String department,
    String? designation,
    List<String> assignedProjectIds = const [],
  }) async {
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

    try {
      final client = ref.read(apiClientProvider);
      await client.post('/users', body: newUser.toJson());
    } catch (_) {
      // Offline fallback
    }
  }

  Future<void> updateUser(UserModel updated) async {
    state = [
      for (final u in state)
        if (u.id == updated.id) updated else u,
    ];

    try {
      final client = ref.read(apiClientProvider);
      await client.put('/users/${updated.id}', body: updated.toJson());
    } catch (_) {
      // Offline fallback
    }
  }

  Future<void> changeRole(String userId, UserRole newRole) async {
    state = [
      for (final u in state)
        if (u.id == userId) u.copyWith(role: newRole) else u,
    ];

    try {
      final client = ref.read(apiClientProvider);
      await client.patch('/users/$userId/role', body: {'role': newRole.name});
    } catch (_) {
      // Offline fallback
    }
  }

  Future<void> toggleActive(String userId) async {
    final user = state.firstWhere((u) => u.id == userId);
    final updated = user.copyWith(isActive: !user.isActive);

    state = [
      for (final u in state)
        if (u.id == userId) updated else u,
    ];

    try {
      final client = ref.read(apiClientProvider);
      await client.patch('/users/$userId/status', body: {'is_active': updated.isActive});
    } catch (_) {
      // Offline fallback
    }
  }
}

final userManagementProvider =
    NotifierProvider<UserManagementNotifier, List<UserModel>>(UserManagementNotifier.new);
