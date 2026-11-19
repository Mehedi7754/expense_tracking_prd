import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/leave_model.dart';
import '../models/comment_model.dart';

final leaveRepositoryProvider = Provider<LeaveRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return LeaveRepository(client);
});

class LeaveAllowance {
  final String userId;
  final int year;
  final String leaveType;
  final int allowedDays;

  const LeaveAllowance({
    required this.userId,
    required this.year,
    required this.leaveType,
    required this.allowedDays,
  });

  factory LeaveAllowance.fromJson(Map<String, dynamic> json) => LeaveAllowance(
    userId: (json['userId'] ?? '').toString(),
    year: (json['year'] as num).toInt(),
    leaveType: (json['leaveType'] ?? '').toString(),
    allowedDays: (json['allowedDays'] as num).toInt(),
  );
}

class LeaveRepository {
  final ApiClient _client;

  LeaveRepository(this._client);

  Future<List<LeaveAllowance>> getAllowances({
    required int year,
    String? userId,
  }) async {
    final query =
        Uri(
          queryParameters: {
            'year': '$year',
            if (userId != null) 'userId': userId,
          },
        ).query;
    final response = await _client.get(
      '${ApiEndpoints.salary}/leave-allowances?$query',
    );
    if (response is! List)
      throw const FormatException('Invalid leave allowance response');
    return response
        .whereType<Map<String, dynamic>>()
        .map(LeaveAllowance.fromJson)
        .toList();
  }

  Future<LeaveAllowance> setAllowance({
    required String userId,
    required int year,
    required String leaveType,
    required int allowedDays,
  }) async {
    final response = await _client.post(
      '${ApiEndpoints.salary}/leave-allowances',
      body: {
        'userId': userId,
        'year': year,
        'leaveType': leaveType,
        'allowedDays': allowedDays,
      },
    );
    if (response is! Map<String, dynamic>)
      throw const FormatException('Invalid leave allowance response');
    return LeaveAllowance.fromJson(response);
  }

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
    dynamic rows = response;
    while (rows is Map<String, dynamic>) {
      final nested = rows['data'] ?? rows['leaves'] ?? rows['results'];
      if (nested == null || identical(nested, rows)) break;
      rows = nested;
    }
    if (rows is! List) return const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(LeaveRecordModel.fromJson)
        .toList();
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
      body: const {},
    );
    if (response is Map<String, dynamic>) {
      return LeaveRecordModel.fromJson(response);
    }
    throw const FormatException(
      'Invalid server response when updating leave request',
    );
  }

  Future<List<CommentModel>> getComments(String leaveId) async {
    dynamic rows = await _client.get(ApiEndpoints.leaveComments(leaveId));
    while (rows is Map<String, dynamic>) {
      final nested = rows['data'] ?? rows['comments'] ?? rows['results'];
      if (nested == null || identical(nested, rows)) break;
      rows = nested;
    }
    if (rows is! List) {
      throw const FormatException(
        'Invalid server response when loading leave clarification messages',
      );
    }
    return rows
        .whereType<Map<String, dynamic>>()
        .map(CommentModel.fromJson)
        .toList();
  }

  Future<CommentModel> addComment(String leaveId, String text) async {
    final response = await _client.post(
      ApiEndpoints.leaveComments(leaveId),
      body: {'comment': text, 'text': text, 'comment_text': text},
    );
    if (response is Map<String, dynamic>) {
      final data =
          response['data'] is Map<String, dynamic>
              ? response['data'] as Map<String, dynamic>
              : response;
      return CommentModel.fromJson(data);
    }
    throw const FormatException(
      'Invalid server response when adding leave comment',
    );
  }
}
