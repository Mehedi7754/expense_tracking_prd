import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/api_client.dart';
import '../core/services/attendance_salary_mock_store.dart';
import '../core/utils/fetch_cache_mixin.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';

const String _kCustomUsersKey = 'gw_custom_users_cache';
const String _kCustomUserPasswordsKey = 'gw_custom_user_passwords_cache';
const String _kDeletedUserIdsKey = 'gw_deleted_user_ids_cache';

/// Authentic database users seeded in PostgreSQL
const List<UserModel> kAuthenticDatabaseUsers = [
  UserModel(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Arif',
    email: 'admin@gw.com',
    role: UserRole.mainAdmin,
    department: 'Corporate Governance',
    designation: 'Managing Director / Admin',
    phone: '+880 1711-000001',
    assignedProjectIds: ['6a836552-904a-4cc3-b063-cce4481fe3a5', 'e29e4218-d7e1-4f28-a34d-0acea710239a'],
  ),
];

class UserManagementNotifier extends Notifier<List<UserModel>> with FetchCacheMixin {
  @override
  List<UserModel> build() {
    _loadCachedUsers();
    return const [];
  }

  bool _isForbiddenUser(UserModel u, Set<String> deletedSet) {
    final lowerName = u.name.trim().toLowerCase();
    final lowerEmail = u.email.trim().toLowerCase();
    final lowerId = u.id.trim().toLowerCase();
    return !u.isActive ||
        deletedSet.contains(lowerId) ||
        deletedSet.contains(lowerEmail) ||
        deletedSet.contains(lowerName) ||
        lowerName.contains('eleanor') ||
        lowerEmail.contains('eleanor') ||
        lowerEmail == 'admin@pfis.com';
  }

  Future<void> _loadCachedUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deletedList = prefs.getStringList(_kDeletedUserIdsKey) ?? [];
      final deletedSet = deletedList.map((e) => e.trim().toLowerCase()).toSet();
      deletedSet.addAll(['cd673242-0a2b-46b4-873f-55f4ca3b8deb', 'admin@pfis.com', 'eleanor vance', 'eleanor']);

      final jsonStr = prefs.getString(_kCustomUsersKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        final customUsers = decoded
            .whereType<Map<String, dynamic>>()
            .map(UserModel.fromJson)
            .where((u) => !_isForbiddenUser(u, deletedSet))
            .toList();

        state = customUsers;
      } else {
        state = kAuthenticDatabaseUsers
            .where((u) => !_isForbiddenUser(u, deletedSet))
            .toList();
      }
      fetchUsers(force: true);
    } catch (_) {
      state = const [];
    }
  }

  Future<void> _persistUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = state.map((u) => u.toJson()).toList();
      await prefs.setString(_kCustomUsersKey, jsonEncode(jsonList));
    } catch (_) {}
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
      final prefs = await SharedPreferences.getInstance();
      final deletedList = prefs.getStringList(_kDeletedUserIdsKey) ?? [];
      final deletedSet = deletedList.map((e) => e.trim().toLowerCase()).toSet();
      deletedSet.addAll(['cd673242-0a2b-46b4-873f-55f4ca3b8deb', 'admin@pfis.com', 'eleanor vance', 'eleanor']);

      List<UserModel>? fetched;
      // 1. Query backend /users endpoint
      try {
        final client = ref.read(apiClientProvider);
        final response = await client.get('/users');
        if (response is List) {
          fetched = response
              .whereType<Map<String, dynamic>>()
              .map(UserModel.fromJson)
              .where((u) => !_isForbiddenUser(u, deletedSet))
              .toList();
        } else if (response is Map<String, dynamic> && response['data'] is List) {
          fetched = (response['data'] as List)
              .whereType<Map<String, dynamic>>()
              .map(UserModel.fromJson)
              .where((u) => !_isForbiddenUser(u, deletedSet))
              .toList();
        }
      } catch (_) {
        // Backend /users offline fallback
      }

      final mergedMap = <String, UserModel>{};
      if (fetched != null) {
        for (final u in fetched) {
          if (!_isForbiddenUser(u, deletedSet)) {
            _addOrUpdateUser(mergedMap, u);
          }
        }
      } else {
        for (final u in state) {
          if (!_isForbiddenUser(u, deletedSet)) {
            _addOrUpdateUser(mergedMap, u);
          }
        }
      }

      state = mergedMap.values.where((u) => !_isForbiddenUser(u, deletedSet)).toList();
      await _persistUsers();
      AttendanceSalaryMockStore.instance.syncUsers(state);
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
    AttendanceSalaryMockStore.instance.syncUsers(users);
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

    // Remove from deleted list if present
    try {
      final prefs = await SharedPreferences.getInstance();
      final deletedList = prefs.getStringList(_kDeletedUserIdsKey) ?? [];
      final updated = deletedList.where((id) => id.toLowerCase() != cleanEmail).toList();
      await prefs.setStringList(_kDeletedUserIdsKey, updated);
    } catch (_) {}

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

    AttendanceSalaryMockStore.instance.syncUser(newUser);

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

    AttendanceSalaryMockStore.instance.syncUser(updated);
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

    if (!updated.isActive) {
      AttendanceSalaryMockStore.instance.removeUser(userId);
    } else {
      AttendanceSalaryMockStore.instance.syncUser(updated);
    }

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
    final matching = state.where((u) =>
        u.id == cleanId ||
        u.id.toLowerCase() == cleanId.toLowerCase() ||
        u.email.trim().toLowerCase() == cleanId.toLowerCase() ||
        u.name.trim().toLowerCase() == cleanId.toLowerCase()).toList();

    final deletedIds = <String>{
      cleanId,
      cleanId.toLowerCase(),
      for (final u in matching) ...[
        u.id,
        u.id.toLowerCase(),
        u.email.trim().toLowerCase(),
        u.name.trim().toLowerCase(),
      ],
    };

    state = state.where((u) =>
        !deletedIds.contains(u.id) &&
        !deletedIds.contains(u.id.toLowerCase()) &&
        !deletedIds.contains(u.email.trim().toLowerCase()) &&
        !deletedIds.contains(u.name.trim().toLowerCase())).toList();
    await _persistUsers();

    try {
      final prefs = await SharedPreferences.getInstance();
      final currentDeleted = prefs.getStringList(_kDeletedUserIdsKey) ?? [];
      final newDeleted = {...currentDeleted, ...deletedIds}.toList();
      await prefs.setStringList(_kDeletedUserIdsKey, newDeleted);
    } catch (_) {}

    for (final id in deletedIds) {
      AttendanceSalaryMockStore.instance.removeUser(id);
    }

    try {
      final client = ref.read(apiClientProvider);
      await client.delete('/users/$cleanId');
    } catch (_) {
      // Offline fallback
    }
  }
}

final userManagementProvider =
    NotifierProvider<UserManagementNotifier, List<UserModel>>(UserManagementNotifier.new);
