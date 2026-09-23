import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/audit_log_model.dart';
import '../models/user_role.dart';

class AuditLogNotifier extends Notifier<List<AuditLogModel>> {
  static final List<AuditLogModel> _initialLogs = [
    AuditLogModel(
      id: 'log_01',
      userId: 'usr_mgr_01',
      userName: 'Sarah Jenkins',
      userRole: UserRole.projectManager,
      action: 'Approved Expense',
      entityType: 'Expense',
      entityId: 'exp_fahim_01',
      details: 'Approved ৳40,000 for AWS Cloud & GPU Cluster (Enterprise Cloud ERP Platform)',
      timestamp: DateTime(2026, 9, 6, 10, 15),
    ),
    AuditLogModel(
      id: 'log_02',
      userId: 'usr_fin_01',
      userName: 'David Chen',
      userRole: UserRole.finance,
      action: 'Approved Justification',
      entityType: 'Expense',
      entityId: 'exp_05',
      details: 'Approved no-receipt justification for emergency late-night server deployment transport (৳20,000).',
      timestamp: DateTime(2026, 9, 14, 10, 00),
    ),
    AuditLogModel(
      id: 'log_03',
      userId: 'usr_fin_01',
      userName: 'David Chen',
      userRole: UserRole.finance,
      action: 'Recorded Revenue',
      entityType: 'Project',
      entityId: 'proj_01',
      details: 'Added ৳10,00,000 Sprint Milestone 4 deliverable payment for Enterprise Cloud ERP Platform.',
      timestamp: DateTime(2026, 6, 15, 11, 00),
    ),
    AuditLogModel(
      id: 'log_04',
      userId: 'usr_adm_01',
      userName: 'Eleanor Vance',
      userRole: UserRole.mainAdmin,
      action: 'Closed Project',
      entityType: 'Project',
      entityId: 'proj_05',
      details: 'Closed Supply Chain SaaS Integration 2025. Final profit: ৳3,00,000 (35.3% margin).',
      timestamp: DateTime(2025, 12, 20, 15, 30),
    ),
    AuditLogModel(
      id: 'log_05',
      userId: 'usr_adm_01',
      userName: 'Eleanor Vance',
      userRole: UserRole.mainAdmin,
      action: 'Updated Office Benefit Rule',
      entityType: 'Settings',
      entityId: 'rule_ob_01',
      details: 'Configured Office Benefit rate to 30% for Government and 25% for Private contracts.',
      timestamp: DateTime(2026, 8, 15, 14, 10),
    ),
  ];

  @override
  List<AuditLogModel> build() => _initialLogs;

  void log({
    required String userId,
    required String userName,
    required UserRole userRole,
    required String action,
    required String entityType,
    required String entityId,
    required String details,
  }) {
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
    state = [entry, ...state];
  }
}

final auditLogProvider =
    NotifierProvider<AuditLogNotifier, List<AuditLogModel>>(AuditLogNotifier.new);
