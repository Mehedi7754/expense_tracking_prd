enum NotificationType {
  expenseApproved,
  expenseRejected,
  budgetWarning,
  commentAdded,
  general;

  String get displayName {
    switch (this) {
      case NotificationType.expenseApproved:
        return 'Expense Approved';
      case NotificationType.expenseRejected:
        return 'Expense Rejected';
      case NotificationType.budgetWarning:
        return 'Budget Warning';
      case NotificationType.commentAdded:
        return 'New Comment';
      case NotificationType.general:
        return 'Notification';
    }
  }

  static NotificationType fromString(String val) {
    switch (val.toLowerCase().replaceAll(' ', '').replaceAll('_', '')) {
      case 'expenseapproved':
        return NotificationType.expenseApproved;
      case 'expenserejected':
        return NotificationType.expenseRejected;
      case 'budgetwarning':
        return NotificationType.budgetWarning;
      case 'commentadded':
        return NotificationType.commentAdded;
      case 'general':
      default:
        return NotificationType.general;
    }
  }
}

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String fullExplanation;
  final NotificationType type;
  final String? relatedExpenseId;
  final String? relatedProjectId;
  final bool isRead;
  final DateTime timestamp;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.fullExplanation,
    required this.type,
    this.relatedExpenseId,
    this.relatedProjectId,
    this.isRead = false,
    required this.timestamp,
  });

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    String? fullExplanation,
    NotificationType? type,
    String? relatedExpenseId,
    String? relatedProjectId,
    bool? isRead,
    DateTime? timestamp,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      fullExplanation: fullExplanation ?? this.fullExplanation,
      type: type ?? this.type,
      relatedExpenseId: relatedExpenseId ?? this.relatedExpenseId,
      relatedProjectId: relatedProjectId ?? this.relatedProjectId,
      isRead: isRead ?? this.isRead,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['type'] ?? 'general').toString();
    return NotificationModel(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? json['userId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      fullExplanation: (json['full_explanation'] ?? json['fullExplanation'] ?? '').toString(),
      type: NotificationType.fromString(typeStr),
      relatedExpenseId: json['related_expense_id']?.toString() ?? json['relatedExpenseId']?.toString(),
      relatedProjectId: json['related_project_id']?.toString() ?? json['relatedProjectId']?.toString(),
      isRead: json['is_read'] ?? json['isRead'] ?? false,
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
      'title': title,
      'message': message,
      'full_explanation': fullExplanation,
      'type': type.name,
      if (relatedExpenseId != null) 'related_expense_id': relatedExpenseId,
      if (relatedProjectId != null) 'related_project_id': relatedProjectId,
      'is_read': isRead,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
