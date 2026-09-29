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

  factory AuditLogModel.fromJson(Map<String, dynamic> json) {
    final roleStr = (json['user_role'] ?? json['userRole'] ?? 'project_member').toString();
    return AuditLogModel(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? json['userId'] ?? '').toString(),
      userName: (json['user_name'] ?? json['userName'] ?? '').toString(),
      userRole: UserRole.fromString(roleStr),
      action: (json['action'] ?? '').toString(),
      entityType: (json['entity_type'] ?? json['entityType'] ?? '').toString(),
      entityId: (json['entity_id'] ?? json['entityId'] ?? '').toString(),
      details: (json['details'] ?? '').toString(),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : (json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
              : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'user_role': userRole.name,
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
