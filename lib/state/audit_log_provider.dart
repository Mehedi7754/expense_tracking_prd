import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/audit_log_model.dart';
import '../models/user_role.dart';

class AuditLogNotifier extends Notifier<List<AuditLogModel>> {
  static final List<AuditLogModel> _initialLogs = [
    AuditLogModel(
      id: 'log_01',
      userId: 'usr_mgr_01',
      userName: 'Sarah Jenkins',
      userRole: UserRole.manager,
      action: 'Approved Expense',
      entityType: 'Expense',
      entityId: 'exp_01',
      details: 'Approved \$145.50 for Software & Tools (Mobile App Modernization)',
      timestamp: DateTime(2026, 9, 11, 10, 15),
    ),
    AuditLogModel(
      id: 'log_02',
      userId: 'usr_mgr_01',
      userName: 'Sarah Jenkins',
      userRole: UserRole.manager,
      action: 'Rejected Expense',
      entityType: 'Expense',
      entityId: 'exp_04',
      details: 'Rejected \$320.00 for Hardware & Devices. Reason: Procurement policy required.',
      timestamp: DateTime(2026, 9, 5, 16, 42),
    ),
    AuditLogModel(
      id: 'log_03',
      userId: 'usr_fin_01',
      userName: 'David Chen',
      userRole: UserRole.finance,
      action: 'Recorded Revenue',
      entityType: 'Project',
      entityId: 'proj_01',
      details: 'Added \$25,000.00 milestone payment for Mobile App Modernization.',
      timestamp: DateTime(2026, 6, 15, 11, 00),
    ),
    AuditLogModel(
      id: 'log_04',
      userId: 'usr_adm_01',
      userName: 'Eleanor Vance',
      userRole: UserRole.admin,
      action: 'Deactivated User',
      entityType: 'User',
      entityId: 'usr_emp_04',
      details: 'Account deactivated for Lucas Wright (Sales & Growth).',
      timestamp: DateTime(2026, 8, 1, 9, 20),
    ),
    AuditLogModel(
      id: 'log_05',
      userId: 'usr_adm_01',
      userName: 'Eleanor Vance',
      userRole: UserRole.admin,
      action: 'Added Category',
      entityType: 'Category',
      entityId: 'cat_07',
      details: 'Created new expense category "Office & Supplies".',
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
