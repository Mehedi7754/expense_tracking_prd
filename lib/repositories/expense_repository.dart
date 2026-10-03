import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/comment_model.dart';
import '../models/expense_model.dart';

class ExpenseRepository {
  final ApiClient _client;

  ExpenseRepository(this._client);

  Future<List<ExpenseModel>> getExpenses({
    String? projectId,
    String? employeeId,
    String? status,
  }) async {
    final queryParams = <String, dynamic>{
      if (projectId != null) 'project_id': projectId,
      if (employeeId != null) 'employee_id': employeeId,
      if (status != null) 'status': status,
    };

    final response = await _client.get(
      ApiEndpoints.expenses,
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );

    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map(ExpenseModel.fromJson)
          .toList();
    } else if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map(ExpenseModel.fromJson)
          .toList();
    }

    return const [];
  }

  Future<ExpenseModel> getExpenseById(String id) async {
    final response = await _client.get(ApiEndpoints.expenseById(id));
    final data = response is Map<String, dynamic> && response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response as Map<String, dynamic>;
    return ExpenseModel.fromJson(data);
  }

  Future<ExpenseModel> createExpense(ExpenseModel expense) async {
    final response = await _client.post(
      ApiEndpoints.expenses,
      body: expense.toJson(),
    );

    final data = response is Map<String, dynamic> && response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response as Map<String, dynamic>;
    return ExpenseModel.fromJson(data);
  }

  Future<ExpenseModel> updateExpense(ExpenseModel expense) async {
    final response = await _client.put(
      ApiEndpoints.expenseById(expense.id),
      body: expense.toJson(),
    );

    final data = response is Map<String, dynamic> && response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response as Map<String, dynamic>;
    return ExpenseModel.fromJson(data);
  }

  Future<ExpenseModel> updateStatus(
    String expenseId,
    ExpenseStatus status, {
    String? rejectionReason,
  }) async {
    dynamic response;
    try {
      if (status == ExpenseStatus.approved) {
        response = await _client.post(
          ApiEndpoints.approveExpense(expenseId),
          body: {'comment': 'Approved by reviewer'},
        );
      } else if (status == ExpenseStatus.rejected) {
        response = await _client.post(
          ApiEndpoints.rejectExpense(expenseId),
          body: {'rejectionReason': rejectionReason ?? 'Rejected by reviewer'},
        );
      } else {
        response = await _client.put(
          ApiEndpoints.expenseById(expenseId),
          body: {'status': status.name},
        );
      }
    } catch (_) {
      // Fallback for endpoints or servers implementing PATCH status or direct PUT
      try {
        response = await _client.put(
          ApiEndpoints.expenseById(expenseId),
          body: {
            'status': status.name,
            if (rejectionReason != null) 'rejection_reason': rejectionReason,
          },
        );
      } catch (_) {
        response = await _client.patch(
          ApiEndpoints.expenseStatus(expenseId),
          body: {
            'status': status.name,
            if (rejectionReason != null) 'rejection_reason': rejectionReason,
          },
        );
      }
    }

    final data = response is Map<String, dynamic> && response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response as Map<String, dynamic>;
    return ExpenseModel.fromJson(data);
  }

  Future<CommentModel> addComment(String expenseId, CommentModel comment) async {
    final response = await _client.post(
      ApiEndpoints.expenseComments(expenseId),
      body: comment.toJson(),
    );

    final data = response is Map<String, dynamic> && response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response as Map<String, dynamic>;
    return CommentModel.fromJson(data);
  }

  Future<ExpenseModel> submitJustification(
    String expenseId, {
    required String reason,
    String? comment,
    String? attachmentUrl,
  }) async {
    final response = await _client.post(
      ApiEndpoints.submitJustification(expenseId),
      body: {
        'justification_reason': reason,
        if (comment != null) 'justification_comment': comment,
        if (attachmentUrl != null) 'justification_attachment_url': attachmentUrl,
      },
    );

    final data = response is Map<String, dynamic> && response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response as Map<String, dynamic>;
    return ExpenseModel.fromJson(data);
  }

  Future<ExpenseModel> reviewJustification(
    String expenseId, {
    required JustificationStatus status,
    String? reviewComment,
  }) async {
    final response = await _client.post(
      ApiEndpoints.reviewJustification(expenseId),
      body: {
        'justification_status': status.name,
        if (reviewComment != null) 'justification_review_comment': reviewComment,
      },
    );

    final data = response is Map<String, dynamic> && response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response as Map<String, dynamic>;
    return ExpenseModel.fromJson(data);
  }
}

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(apiClientProvider));
});
