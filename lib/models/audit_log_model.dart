import 'user_role.dart';

class AuditLogModel {
  final String id;
  final String userId;
  final String userName;
  final UserRole userRole;
  final String action;
  final String entityType; // e.g. Expense, Project, User, Category
  final String entityId;
  final String details;
  final DateTime timestamp;

  const AuditLogModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.details,
    required this.timestamp,
  });
}
