import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/api_client.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';

const String _kCustomUsersKey = 'gw_custom_users_cache';

class UserManagementNotifier extends Notifier<List<UserModel>> {
  static bool isDummyUser(UserModel u) {
    const dummyIds = {'usr_adm_01', 'usr_mgr_01', 'usr_emp_01', 'usr_emp_03', 'usr_emp_04', 'usr_fin_01'};
    const dummyNames = {
      'Eleanor Vance',
      'Sarah Jenkins',
      'Fahim Ahmed',
      'Karim Ullah',
      'Tanvir Hossain',
      'Michael Chang',
    };
    return dummyIds.contains(u.id) || dummyNames.contains(u.name);
  }

  @override
  List<UserModel> build() {
    _loadCachedUsers();
    return const [];
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
            .where((u) => !isDummyUser(u))
            .toList();

        state = customUsers;
        await prefs.setString(
          _kCustomUsersKey,
          jsonEncode(customUsers.map((u) => u.toJson()).toList()),
        );
      } else {
        state = const [];
      }
    } catch (e) {
      debugPrint('[UserManagementNotifier] Error loading cached users: $e');
      state = const [];
    }
  }

  Future<void> _persistUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final realUsers = state.where((u) => !isDummyUser(u)).toList();
      final jsonList = realUsers.map((u) => u.toJson()).toList();
      await prefs.setString(_kCustomUsersKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[UserManagementNotifier] Error persisting users: $e');
    }
  }

  Future<void> fetchUsers() async {
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get('/users');
      List<UserModel> fetched = [];
      if (response is List) {
        fetched = response
            .whereType<Map<String, dynamic>>()
            .map(UserModel.fromJson)
            .where((u) => !isDummyUser(u))
            .toList();
      } else if (response is Map<String, dynamic> && response['data'] is List) {
        fetched = (response['data'] as List)
            .whereType<Map<String, dynamic>>()
            .map(UserModel.fromJson)
            .where((u) => !isDummyUser(u))
            .toList();
      }
      if (fetched.isNotEmpty) {
        // Merge with existing users by id/email
        final mergedMap = <String, UserModel>{};
        for (final u in state) {
          mergedMap[u.id] = u;
          if (u.email.isNotEmpty) mergedMap[u.email.toLowerCase()] = u;
        }
        for (final u in fetched) {
          mergedMap[u.id] = u;
          if (u.email.isNotEmpty) mergedMap[u.email.toLowerCase()] = u;
        }
        state = mergedMap.values.toSet().toList();
        await _persistUsers();
      }
    } catch (_) {
      // Keep existing state on network disconnect
    }
  }

  Future<List<UserModel>> searchUsers(String query) async {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return state;

    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get('/users/search?q=${Uri.encodeComponent(clean)}');
      List<UserModel> fetched = [];
      if (response is List) {
        fetched = response
            .whereType<Map<String, dynamic>>()
            .map(UserModel.fromJson)
            .where((u) => !isDummyUser(u))
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
    final user = state.firstWhere((u) => u.id == userId);
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
    final user = state.firstWhere((u) => u.id == userId);
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
