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
}
