import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/audit_log_model.dart';
import '../models/user_role.dart';
import '../repositories/audit_log_repository.dart';

class AuditLogNotifier extends Notifier<List<AuditLogModel>> {
  @override
  List<AuditLogModel> build() {
    // Default clean empty state on startup (no hardcoded demo logs)
    return const [];
  }

  Future<void> fetchLogs() async {
    try {
      final repo = ref.read(auditLogRepositoryProvider);
      final logs = await repo.getAuditLogs();
      state = logs;
    } catch (_) {
      // Keep existing state on network disconnect
    }
  }

  void setLogs(List<AuditLogModel> logs) {
    state = logs;
  }

  Future<void> log({
    required String userId,
    required String userName,
    required UserRole userRole,
    required String action,
    required String entityType,
    required String entityId,
    required String details,
  }) async {
    final entry = AuditLogModel(
      id: 'log_${DateTime.now().microsecondsSinceEpoch}',
      userId: userId,
      userName: userName,
      userRole: userRole,
      action: action,
      entityType: entityType,
      entityId: entityId,
      details: details,
      timestamp: DateTime.now(),
    );

    // Optimistic local update
    state = [entry, ...state];

    try {
      final repo = ref.read(auditLogRepositoryProvider);
      await repo.createAuditLog(entry);
    } catch (_) {
      // Offline fallback
    }
  }
}

final auditLogProvider =
    NotifierProvider<AuditLogNotifier, List<AuditLogModel>>(AuditLogNotifier.new);
