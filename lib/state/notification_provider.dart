import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';

class NotificationNotifier extends Notifier<List<NotificationModel>> {
  static final List<NotificationModel> _initialNotifications = [
    NotificationModel(
      id: 'notif_01',
      userId: 'usr_emp_01',
      title: 'Expense Claim Approved',
      message: 'Your \$145.50 claim for Figma seat license was approved by Sarah Jenkins.',
      fullExplanation:
          'Expense ID: exp_01\nAmount: \$145.50\nCategory: Software & Tools\nProject: Mobile App Modernization\n\nApprover Sarah Jenkins approved this expense under the agreed Q3 tools budget.',
      type: NotificationType.expenseApproved,
      relatedExpenseId: 'exp_01',
      isRead: false,
      timestamp: DateTime(2026, 9, 11, 10, 15),
    ),
    NotificationModel(
      id: 'notif_02',
      userId: 'usr_emp_01',
      title: 'Expense Claim Rejected',
      message: 'Your \$320.00 claim for GPU Accelerator Enclosure was rejected.',
      fullExplanation:
          'Expense ID: exp_04\nAmount: \$320.00\nCategory: Hardware & Devices\nProject: AI Analytics Pipeline\n\nReason given by Approver:\n"Device purchases must go through central procurement rather than expense claims. Please coordinate with IT infrastructure to request internal hardware requisition."',
      type: NotificationType.expenseRejected,
      relatedExpenseId: 'exp_04',
      isRead: false,
      timestamp: DateTime(2026, 9, 5, 16, 42),
    ),
    NotificationModel(
      id: 'notif_03',
      userId: 'usr_emp_01',
      title: 'Budget Alert (>80% Consumed)',
      message: 'Project "AI Analytics Pipeline" has consumed 84.5% of its allocated budget.',
      fullExplanation:
          'Project: AI Analytics Pipeline\nTotal Budget: \$25,000.00\nCurrent Spend: \$21,125.00 (84.5%)\n\nAttention: This project has breached the 80% threshold policy. Further expense submissions may require finance director authorization.',
      type: NotificationType.budgetWarning,
      relatedProjectId: 'proj_03',
      isRead: true,
      timestamp: DateTime(2026, 9, 14, 8, 30),
    ),
    NotificationModel(
      id: 'notif_04',
      userId: 'usr_emp_01',
      title: 'New Reviewer Comment',
      message: 'Sarah Jenkins commented on your dinner expense claim.',
      fullExplanation:
          'Expense: Sprint retrospective team working dinner\nComment:\n"Did the client attendee list include external directors?"',
      type: NotificationType.commentAdded,
      relatedExpenseId: 'exp_02',
      isRead: true,
      timestamp: DateTime(2026, 9, 16, 9, 30),
    ),
  ];

  @override
  List<NotificationModel> build() => _initialNotifications;

  void markAsRead(String id) {
    state = [
      for (final n in state)
        if (n.id == id) n.copyWith(isRead: true) else n,
    ];
  }

  void markAllAsRead() {
    state = [
      for (final n in state) n.copyWith(isRead: true),
    ];
  }

  void addNotification({
    required String userId,
    required String title,
    required String message,
    required String fullExplanation,
    required NotificationType type,
    String? relatedExpenseId,
    String? relatedProjectId,
  }) {
    final newNotif = NotificationModel(
      id: 'notif_${DateTime.now().microsecondsSinceEpoch}',
      userId: userId,
      title: title,
      message: message,
      fullExplanation: fullExplanation,
      type: type,
      relatedExpenseId: relatedExpenseId,
      relatedProjectId: relatedProjectId,
      isRead: false,
      timestamp: DateTime.now(),
    );
    state = [newNotif, ...state];
  }
}

final notificationProvider =
    NotifierProvider<NotificationNotifier, List<NotificationModel>>(NotificationNotifier.new);
