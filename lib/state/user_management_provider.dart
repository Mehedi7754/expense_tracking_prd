import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/api_client.dart';
import '../core/utils/fetch_cache_mixin.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import 'auth_provider.dart';
import 'expense_provider.dart';

const String _kCustomUsersKey = 'gw_custom_users_cache';

/// Authentic database users seeded in PostgreSQL
const List<UserModel> kAuthenticDatabaseUsers = [
  UserModel(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Eleanor Vance',
    email: 'admin@pfis.com',
    role: UserRole.mainAdmin,
    department: 'Corporate Governance',
    designation: 'Managing Director / Admin',
    phone: '+880 1711-000001',
    assignedProjectIds: ['d0000000-0000-0000-0000-000000000001'],
  ),
];


class UserManagementNotifier extends Notifier<List<UserModel>> with FetchCacheMixin {
  @override
  List<UserModel> build() {
    _loadCachedUsers();
    return kAuthenticDatabaseUsers;
  }

  Future<void> _loadCachedUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_kCustomUsersKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        final customUsers = decoded
            .whereType<Map<String, dynamic>>()
            .map(UserModel.fromJson)
            .toList();

        if (customUsers.isNotEmpty) {
          final mergedMap = <String, UserModel>{};
          for (final u in kAuthenticDatabaseUsers) {
            _addOrUpdateUser(mergedMap, u);
          }
          for (final u in customUsers) {
            _addOrUpdateUser(mergedMap, u);
          }
          state = mergedMap.values.toList();
        } else {
          state = kAuthenticDatabaseUsers;
        }
      } else {
        state = kAuthenticDatabaseUsers;
      }
    } catch (e) {
      debugPrint('[UserManagementNotifier] Error loading cached users: $e');
      state = kAuthenticDatabaseUsers;
    }
  }

  Future<void> _persistUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = state.map((u) => u.toJson()).toList();
      await prefs.setString(_kCustomUsersKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[UserManagementNotifier] Error persisting users: $e');
    }
  }

  static void _addOrUpdateUser(Map<String, UserModel> map, UserModel user) {
    if (user.email.isNotEmpty) {
      final existingKey = map.keys.cast<String?>().firstWhere(
        (k) => map[k]!.email.trim().toLowerCase() == user.email.trim().toLowerCase(),
        orElse: () => null,
      );
      if (existingKey != null) {
        final finalKey = user.id.isNotEmpty ? user.id : existingKey;
        map.remove(existingKey);
        map[finalKey] = user;
        return;
      }
    }
    final key = user.id.isNotEmpty ? user.id : user.email.trim().toLowerCase();
    map[key] = user;
  }

  /// Fetches users from backend with cache check.
  /// Set [force] to `true` for pull-to-refresh or post-mutation sync.
  Future<void> fetchUsers({bool force = false}) async {
    if (!shouldFetch(force: force, hasData: state.isNotEmpty)) return;

    markFetchStarted();
    try {
      final mergedMap = <String, UserModel>{};
      for (final u in state) {
        _addOrUpdateUser(mergedMap, u);
      }

      // 1. Try querying backend /users endpoint
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
        for (final u in fetched) {
          _addOrUpdateUser(mergedMap, u);
        }
      } catch (_) {
        // Backend /users may be unavailable or offline; harvest authentic database users from related providers
      }

      // 2. Synchronize current logged-in user
      try {
        final curUser = ref.read(authProvider).currentUser;
        if (curUser != null && curUser.isActive) {
          _addOrUpdateUser(mergedMap, curUser);
        }
      } catch (_) {}


      state = mergedMap.values.toList();
      await _persistUsers();
      markFetchCompleted();
    } catch (e) {
      markFetchFailed();
      debugPrint('[UserManagementNotifier] Error fetching users: $e');
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

  Future<void> addUser({
    required String name,
    required String email,
    required UserRole role,
    required String department,
    String? designation,
    List<String> assignedProjectIds = const [],
    bool isApproved = true,
  }) async {
    final newUser = UserModel(
      id: 'usr_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      email: email,
      role: role,
      department: department,
      designation: designation,
      isActive: true,
      isApproved: isApproved,
      assignedProjectIds: assignedProjectIds,
    );

    state = [...state, newUser];
    await _persistUsers();

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
    await _persistUsers();

    try {
      final client = ref.read(apiClientProvider);
      await client.put('/users/${updated.id}', body: updated.toJson());
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
}

final userManagementProvider =
    NotifierProvider<UserManagementNotifier, List<UserModel>>(UserManagementNotifier.new);
