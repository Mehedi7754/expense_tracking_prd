enum NotificationType {
  expenseApproved,
  expenseRejected,
  expenseSubmitted,
  justificationSubmitted,
  justificationApproved,
  justificationRejected,
  projectAssigned,
  budgetWarning,
  budgetCritical,
  commentAdded,
  attendanceReminder,
  attendanceLate,
  attendanceEarly,
  absenceDeducted,
  salaryReady,
  payrollFinalized,
  revenueReceived,
  memberAdded,
  userRegistration,
  securityAlert,
  general;

  String get displayName {
    switch (this) {
      case NotificationType.expenseApproved:
        return 'Expense Approved';
      case NotificationType.expenseRejected:
        return 'Expense Rejected';
      case NotificationType.expenseSubmitted:
        return 'New Submission';
      case NotificationType.justificationSubmitted:
        return 'Justification Submitted';
      case NotificationType.justificationApproved:
        return 'Justification Approved';
      case NotificationType.justificationRejected:
        return 'Justification Rejected';
      case NotificationType.projectAssigned:
        return 'Project Assignment';
      case NotificationType.budgetWarning:
        return 'Budget Warning';
      case NotificationType.budgetCritical:
        return 'Critical Budget Alert';
      case NotificationType.commentAdded:
        return 'New Comment';
      case NotificationType.attendanceReminder:
        return 'Attendance Reminder';
      case NotificationType.attendanceLate:
        return 'Late Check-in';
      case NotificationType.attendanceEarly:
        return 'Early Check-Out';
      case NotificationType.absenceDeducted:
        return 'Absence Deduction';
      case NotificationType.salaryReady:
        return 'Salary Statement';
      case NotificationType.payrollFinalized:
        return 'Payroll Finalized';
      case NotificationType.revenueReceived:
        return 'Revenue Received';
      case NotificationType.memberAdded:
        return 'Team Update';
      case NotificationType.userRegistration:
        return 'New User';
      case NotificationType.securityAlert:
        return 'Security Alert';
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
      case 'expensesubmitted':
        return NotificationType.expenseSubmitted;
      case 'justificationsubmitted':
        return NotificationType.justificationSubmitted;
      case 'justificationapproved':
        return NotificationType.justificationApproved;
      case 'justificationrejected':
        return NotificationType.justificationRejected;
      case 'projectassigned':
        return NotificationType.projectAssigned;
      case 'budgetwarning':
        return NotificationType.budgetWarning;
      case 'budgetcritical':
        return NotificationType.budgetCritical;
      case 'commentadded':
        return NotificationType.commentAdded;
      case 'attendancereminder':
        return NotificationType.attendanceReminder;
      case 'attendancelate':
        return NotificationType.attendanceLate;
      case 'attendanceearly':
        return NotificationType.attendanceEarly;
      case 'absencededucted':
        return NotificationType.absenceDeducted;
      case 'salaryready':
        return NotificationType.salaryReady;
      case 'payrollfinalized':
        return NotificationType.payrollFinalized;
      case 'revenuereceived':
        return NotificationType.revenueReceived;
      case 'memberadded':
        return NotificationType.memberAdded;
      case 'userregistration':
        return NotificationType.userRegistration;
      case 'securityalert':
        return NotificationType.securityAlert;
      case 'general':
      default:
        return NotificationType.general;
    }
  }
}


class NotificationModel {
  final String id;
  final String userId;
  final String? actorId;
  final String? actorName;
  final String? actorAvatarUrl;
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
    this.actorId,
    this.actorName,
    this.actorAvatarUrl,
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
    String? actorId,
    String? actorName,
    String? actorAvatarUrl,
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
      actorId: actorId ?? this.actorId,
      actorName: actorName ?? this.actorName,
      actorAvatarUrl: actorAvatarUrl ?? this.actorAvatarUrl,
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
      actorId: json['actor_id']?.toString() ?? json['actorId']?.toString(),
      actorName: json['actor_name']?.toString() ?? json['actorName']?.toString(),
      actorAvatarUrl: json['actor_avatar_url']?.toString() ?? json['actorAvatarUrl']?.toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      fullExplanation: (json['full_explanation'] ?? json['fullExplanation'] ?? '').toString(),
      type: NotificationType.fromString(typeStr),
      relatedExpenseId: json['related_expense_id']?.toString() ?? json['relatedExpenseId']?.toString(),
      relatedProjectId: json['related_project_id']?.toString() ?? json['relatedProjectId']?.toString(),
      isRead: json['is_read'] ?? json['isRead'] ?? false,
      timestamp: () {
        for (final key in ['createdAt', 'created_at', 'timestamp', 'date']) {
          final val = json[key];
          if (val != null) {
            final str = val.toString().trim();
            if (str.isNotEmpty && str != 'null') {
              final parsed = DateTime.tryParse(str);
              if (parsed != null) {
                return parsed.toLocal();
              }
            }
          }
        }
        return DateTime.now();
      }(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      if (actorId != null) 'actor_id': actorId,
      if (actorName != null) 'actor_name': actorName,
      if (actorAvatarUrl != null) 'actor_avatar_url': actorAvatarUrl,
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
