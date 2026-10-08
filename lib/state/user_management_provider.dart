import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/api_client.dart';
import '../core/utils/fetch_cache_mixin.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';

const String _kCustomUsersKey = 'gw_custom_users_cache';
const String _kCustomUserPasswordsKey = 'gw_custom_user_passwords_cache';
class UserManagementNotifier extends Notifier<List<UserModel>> with FetchCacheMixin {
  @override
  List<UserModel> build() {
    fetchUsers(force: true);
    return const [];
  }

  Future<void> _persistUsers() async {
    // No-op: server is the single source of truth
  }

  static Future<void> _saveLocalPassword(String email, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCustomUserPasswordsKey);
      Map<String, dynamic> map = {};
      if (raw != null && raw.isNotEmpty) {
        map = jsonDecode(raw) as Map<String, dynamic>;
      }
      map[email.trim().toLowerCase()] = password;
      await prefs.setString(_kCustomUserPasswordsKey, jsonEncode(map));
    } catch (_) {}
  }

  static Future<String?> getLocalPassword(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCustomUserPasswordsKey);
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        return map[email.trim().toLowerCase()] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Fetches users from backend with cache check.
  /// Set [force] to `true` for pull-to-refresh or post-mutation sync.
  Future<void> fetchUsers({bool force = false}) async {
    if (!shouldFetch(force: force, hasData: state.isNotEmpty)) return;

    markFetchStarted();
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get('/users');
      List<UserModel> fetched = [];
      if (response is List) {
        fetched = response
            .whereType<Map<String, dynamic>>()
            .map(UserModel.fromJson)
            .where((u) => u.isActive)
            .toList();
      } else if (response is Map<String, dynamic> && response['data'] is List) {
        fetched = (response['data'] as List)
            .whereType<Map<String, dynamic>>()
            .map(UserModel.fromJson)
            .where((u) => u.isActive)
            .toList();
      }

      if (fetched.isNotEmpty || force) {
        state = fetched;
        await _persistUsers();
      }
      markFetchCompleted();
    } catch (_) {
      markFetchFailed();
    }
  }

  Future<List<UserModel>> searchUsers(String query) async {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return state;

    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get(
        '/users/search',
        queryParams: {'q': clean},
      );
      List<UserModel> fetched = [];
      if (response is List) {
        fetched = response
            .whereType<Map<String, dynamic>>()
            .map(UserModel.fromJson)
            .toList();
      }
      if (fetched.isNotEmpty) {
        final existingIds = state.map((u) => u.id).toSet();
        final toAdd = fetched.where((u) => !existingIds.contains(u.id)).toList();
        if (toAdd.isNotEmpty) {
          state = [...state, ...toAdd];
          await _persistUsers();
        }
      }
    } catch (_) {}

    return state.where((u) {
      return u.name.toLowerCase().contains(clean) ||
          u.email.toLowerCase().contains(clean) ||
          u.department.toLowerCase().contains(clean);
    }).toList();
  }

  Future<UserModel?> findOrAddMemberByEmail(String rawEmail, {String? name}) async {
    final email = rawEmail.trim().toLowerCase();
    if (email.isEmpty) return null;

    // 1. Check in local state
    for (final u in state) {
      if (u.email.trim().toLowerCase() == email) {
        return u;
      }
    }

    // 2. Try fetching from backend search endpoint
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get('/users/search?email=${Uri.encodeComponent(email)}');
      if (response is List && response.isNotEmpty) {
        final user = UserModel.fromJson(response.first as Map<String, dynamic>);
        state = [...state, user];
        await _persistUsers();
        return user;
      }
    } catch (_) {}

    // 3. Fallback: Create and persist new user entry with this email
    final fallbackUser = UserModel(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      name: name?.trim().isNotEmpty == true ? name!.trim() : email.split('@').first,
      email: email,
      role: UserRole.projectMember,
      department: 'Operations',
      isActive: true,
      isApproved: true,
    );

    state = [...state, fallbackUser];
    await _persistUsers();
    return fallbackUser;
  }

  void setUsers(List<UserModel> users) {
    state = users;
    _persistUsers();
  }

  Future<UserModel> addUser({
    required String name,
    required String email,
    required UserRole role,
    required String department,
    String? designation,
    String? password,
    List<String> assignedProjectIds = const [],
    bool isApproved = true,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final pwd = (password != null && password.trim().isNotEmpty) ? password.trim() : 'password123';
    await _saveLocalPassword(cleanEmail, pwd);

    var newUser = UserModel(
      id: 'usr_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      email: cleanEmail,
      role: role,
      department: department.trim(),
      designation: designation?.trim(),
      isActive: true,
      isApproved: isApproved,
      assignedProjectIds: assignedProjectIds,
    );

    state = [...state, newUser];
    await _persistUsers();

    try {
      final client = ref.read(apiClientProvider);
      final body = {
        ...newUser.toJson(),
        'password': pwd,
      };
      final res = await client.post('/users', body: body);
      if (res is Map<String, dynamic>) {
        final serverUser = UserModel.fromJson(res);
        if (serverUser.id.isNotEmpty) {
          newUser = serverUser;
          state = [
            for (final u in state)
              if (u.email.trim().toLowerCase() == cleanEmail || u.id == newUser.id) newUser else u,
          ];
          await _persistUsers();
        }
      }
    } catch (_) {
      // Offline fallback
    }

    return newUser;
  }

  Future<void> updateUser(UserModel updated, {String? password}) async {
    state = [
      for (final u in state)
        if (u.id == updated.id || (u.email.isNotEmpty && u.email.trim().toLowerCase() == updated.email.trim().toLowerCase())) updated else u,
    ];
    await _persistUsers();

    if (password != null && password.trim().isNotEmpty) {
      await _saveLocalPassword(updated.email, password.trim());
    }

    try {
      final client = ref.read(apiClientProvider);
      final body = {
        ...updated.toJson(),
        if (password != null && password.trim().isNotEmpty) 'password': password.trim(),
      };
      await client.put('/users/${updated.id}', body: body);
    } catch (_) {
      // Offline fallback
    }
  }

  Future<void> assignUserToProject(String userId, String projectId) async {
    state = [
      for (final u in state)
        if (u.id == userId)
          u.copyWith(
            assignedProjectIds: u.assignedProjectIds.contains(projectId)
                ? u.assignedProjectIds
                : [...u.assignedProjectIds, projectId],
          )
        else
          u,
    ];
    await _persistUsers();
  }

  Future<void> unassignUserFromProject(String userId, String projectId) async {
    state = [
      for (final u in state)
        if (u.id == userId)
          u.copyWith(
            assignedProjectIds: u.assignedProjectIds.where((id) => id != projectId).toList(),
          )
        else
          u,
    ];
    await _persistUsers();
  }

  Future<void> changeRole(String userId, UserRole newRole) async {
    state = [
      for (final u in state)
        if (u.id == userId) u.copyWith(role: newRole) else u,
    ];
    await _persistUsers();

    try {
      final client = ref.read(apiClientProvider);
      await client.patch('/users/$userId/role', body: {'role': newRole.name});
    } catch (_) {
      // Offline fallback
    }
  }

  Future<void> toggleActive(String userId) async {
    final idx = state.indexWhere((u) => u.id == userId);
    if (idx == -1) return;
    final user = state[idx];
    final updated = user.copyWith(isActive: !user.isActive);

    state = [
      for (final u in state)
        if (u.id == userId) updated else u,
    ];
    await _persistUsers();

    try {
      final client = ref.read(apiClientProvider);
      await client.patch('/users/$userId/status', body: {'is_active': updated.isActive});
    } catch (_) {
      // Offline fallback
    }
  }

  Future<void> approveUser(String userId) async {
    final idx = state.indexWhere((u) => u.id == userId);
    if (idx == -1) return;
    final user = state[idx];
    final updated = user.copyWith(isApproved: true, isActive: true);

    state = [
      for (final u in state)
        if (u.id == userId) updated else u,
    ];
    await _persistUsers();

    try {
      final client = ref.read(apiClientProvider);
      await client.patch('/users/$userId/status', body: {'is_active': true, 'is_approved': true});
    } catch (_) {
      // Offline fallback
    }
  }

  Future<void> deleteUser(String userId) async {
    final cleanId = userId.trim();
    state = state.where((u) => u.id != cleanId).toList();
    await _persistUsers();

    try {
      final client = ref.read(apiClientProvider);
      await client.delete('/users/$cleanId');
    } catch (_) {}
  }
}

final userManagementProvider =
    NotifierProvider<UserManagementNotifier, List<UserModel>>(UserManagementNotifier.new);
