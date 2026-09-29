import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/audit_log_model.dart';

class AuditLogRepository {
  final ApiClient _client;

  AuditLogRepository(this._client);

  Future<List<AuditLogModel>> getAuditLogs() async {
    final response = await _client.get(ApiEndpoints.auditLogs);

    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map(AuditLogModel.fromJson)
          .toList();
    } else if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map(AuditLogModel.fromJson)
          .toList();
    }

    return const [];
  }

  Future<AuditLogModel> createAuditLog(AuditLogModel log) async {
    final response = await _client.post(
      ApiEndpoints.auditLogs,
      body: log.toJson(),
    );

    final data = response is Map<String, dynamic> && response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response as Map<String, dynamic>;
    return AuditLogModel.fromJson(data);
  }
}

final auditLogRepositoryProvider = Provider<AuditLogRepository>((ref) {
  return AuditLogRepository(ref.watch(apiClientProvider));
});
