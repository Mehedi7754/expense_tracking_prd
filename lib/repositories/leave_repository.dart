import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/leave_model.dart';

final leaveRepositoryProvider = Provider<LeaveRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return LeaveRepository(client);
});

class LeaveRepository {
  final ApiClient _client;

  LeaveRepository(this._client);

  /// Fetches leaves for the given user, or all visible leaves if admin/finance.
  Future<List<LeaveRecordModel>> getLeaves({
    String? userId,
    int? month,
    int? year,
  }) async {
    final queryParams = <String, String>{};
    if (userId != null && userId.isNotEmpty) queryParams['userId'] = userId;
    if (month != null) queryParams['month'] = month.toString();
    if (year != null) queryParams['year'] = year.toString();

    String url = ApiEndpoints.leaves;
    if (queryParams.isNotEmpty) {
      final qs = Uri(queryParameters: queryParams).query;
      url = '$url?$qs';
    }

    final response = await _client.get(url);
    if (response is List) {
      return response
          .map(
            (item) => LeaveRecordModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    }
    return const [];
  }

  /// Submits a new leave application to the live backend.
  Future<LeaveRecordModel> createLeave({
    required String userId,
    required String startDate,
    required String endDate,
    required String leaveType,
    required String reason,
    bool isApproved = false,
  }) async {
    final response = await _client.post(
      ApiEndpoints.leaves,
      body: {
        'userId': userId,
        'startDate': startDate,
        'endDate': endDate,
        'leaveType': leaveType,
        'reason': reason,
        'isApproved': isApproved,
      },
    );

    if (response is Map<String, dynamic>) {
      return LeaveRecordModel.fromJson(response);
    }
    throw const FormatException('Invalid server response when creating leave');
  }

  /// Cancels / deletes a pending leave request.
  Future<bool> deleteLeave(String id) async {
    final url = ApiEndpoints.leaveById(id);
    await _client.delete(url);
    return true;
  }

  Future<LeaveRecordModel> decideLeave(
    String id, {
    required bool approved,
  }) async {
    final response = await _client.post(
      '${ApiEndpoints.leaveById(id)}/${approved ? 'approve' : 'reject'}',
    );
    if (response is Map<String, dynamic>) {
      return LeaveRecordModel.fromJson(response);
    }
    throw const FormatException(
      'Invalid server response when updating leave request',
    );
  }
}
