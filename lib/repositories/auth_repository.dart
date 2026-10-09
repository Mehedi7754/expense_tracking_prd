import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/user_model.dart';

class AuthRepository {
  final ApiClient _client;

  AuthRepository(this._client);

  Future<UserModel> login(String email, String password) async {
    final response = await _client.post(
      ApiEndpoints.login,
      body: {
        'email': email.trim(),
        'password': password,
      },
    );

    if (response is Map<String, dynamic>) {
      final token = response['token'] ?? response['access_token'];
      if (token != null) {
        _client.setAuthToken(token.toString());
      }
      final userData = response['user'] is Map<String, dynamic>
          ? response['user'] as Map<String, dynamic>
          : response;
      return UserModel.fromJson(userData);
    }

    throw const FormatException('Invalid authentication response structure');
  }

  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    required String role,
    required String department,
    String? designation,
  }) async {
    final response = await _client.post(
      ApiEndpoints.register,
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'role': role,
        'department': department.trim(),
        if (designation != null && designation.trim().isNotEmpty)
          'designation': designation.trim(),
      },
    );

    if (response is Map<String, dynamic>) {
      final token = response['token'] ?? response['access_token'];
      if (token != null) {
        _client.setAuthToken(token.toString());
      }
      final userData = response['user'] is Map<String, dynamic>
          ? response['user'] as Map<String, dynamic>
          : response;
      return UserModel.fromJson(userData);
    }

    throw const FormatException('Invalid registration response structure');
  }

  Future<UserModel?> getCurrentUser() async {
    if (_client.authToken == null) return null;
    try {
      final response = await _client.get(ApiEndpoints.me);
      if (response is Map<String, dynamic>) {
        final userData = response['user'] is Map<String, dynamic>
            ? response['user'] as Map<String, dynamic>
            : response;
        return UserModel.fromJson(userData);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await _client.post(ApiEndpoints.logout);
    } catch (_) {
      // Ignore network errors on logout
    } finally {
      _client.clearAuthToken();
    }
  }

  Future<UserModel> updateProfile(Map<String, dynamic> updates) async {
    final response = await _client.patch(
      ApiEndpoints.updateProfile,
      body: updates,
    );

    if (response is Map<String, dynamic>) {
      final userData = response['user'] is Map<String, dynamic>
          ? response['user'] as Map<String, dynamic>
          : response;
      return UserModel.fromJson(userData);
    }

    throw const FormatException('Invalid profile update response structure');
  }

  Future<UserModel?> updateAvatar(String? avatarUrl) async {
    try {
      final response = await _client.put(
        '/auth/avatar',
        body: {'avatarUrl': avatarUrl},
      );
      if (response is Map<String, dynamic>) {
        final userData = response['user'] is Map<String, dynamic>
            ? response['user'] as Map<String, dynamic>
            : response;
        return UserModel.fromJson(userData);
      }
    } catch (_) {
      try {
        final response = await _client.patch(
          ApiEndpoints.updateProfile,
          body: {'avatar_url': avatarUrl},
        );
        if (response is Map<String, dynamic>) {
          final userData = response['user'] is Map<String, dynamic>
              ? response['user'] as Map<String, dynamic>
              : response;
          return UserModel.fromJson(userData);
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _client.post(
      '/auth/change-password',
      body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }

  Future<void> requestForgotPassword(String email) async {
    await _client.post(
      ApiEndpoints.forgotPassword,
      body: {'email': email.trim()},
    );
  }

  Future<bool> verifyOtp(String email, String otp) async {
    final res = await _client.post(
      '/auth/verify-otp',
      body: {
        'email': email.trim(),
        'otp': otp.trim(),
      },
    );
    if (res is Map<String, dynamic>) {
      return res['valid'] == true || res['success'] == true;
    }
    return true;
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    await _client.post(
      ApiEndpoints.resetPassword,
      body: {
        'email': email.trim(),
        'otp': otp.trim(),
        'newPassword': newPassword,
      },
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});
