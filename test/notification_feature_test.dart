import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_tracking_prd/models/notification_model.dart';
import 'package:expense_tracking_prd/state/notification_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Notification Model & Enum Tests', () {
    test('NotificationType enum supports all required types', () {
      expect(NotificationType.expenseSubmitted.displayName, equals('New Submission'));
      expect(NotificationType.attendanceReminder.displayName, equals('Attendance Reminder'));
      expect(NotificationType.attendanceLate.displayName, equals('Late Check-in'));
      expect(NotificationType.absenceDeducted.displayName, equals('Absence Deduction'));
      expect(NotificationType.salaryReady.displayName, equals('Salary Statement'));
      expect(NotificationType.payrollFinalized.displayName, equals('Payroll Finalized'));
      expect(NotificationType.revenueReceived.displayName, equals('Revenue Received'));
      expect(NotificationType.memberAdded.displayName, equals('Team Update'));
      expect(NotificationType.userRegistration.displayName, equals('New User'));
      expect(NotificationType.securityAlert.displayName, equals('Security Alert'));
    });

    test('NotificationType.fromString parses snake_case and camelCase correctly', () {
      expect(
        NotificationType.fromString('expense_submitted'),
        equals(NotificationType.expenseSubmitted),
      );
      expect(
        NotificationType.fromString('attendance_reminder'),
        equals(NotificationType.attendanceReminder),
      );
      expect(
        NotificationType.fromString('absence_deducted'),
        equals(NotificationType.absenceDeducted),
      );
      expect(
        NotificationType.fromString('salary_ready'),
        equals(NotificationType.salaryReady),
      );
      expect(
        NotificationType.fromString('unknown_type'),
        equals(NotificationType.general),
      );
    });

    test('NotificationModel serialization and deserialization works correctly', () {
      final notif = NotificationModel(
        id: 'n_123',
        userId: 'u_456',
        title: 'New Expense Claim',
        message: 'Claim submitted for Review',
        fullExplanation: 'Full claim explanation text',
        type: NotificationType.expenseSubmitted,
        isRead: false,
        timestamp: DateTime.parse('2026-10-03T12:00:00Z'),
        relatedExpenseId: 'exp_789',
        relatedProjectId: 'proj_001',
      );

      final json = notif.toJson();
      expect(json['id'], equals('n_123'));
      expect(json['user_id'], equals('u_456'));
      expect(json['title'], equals('New Expense Claim'));
      expect(json['type'], equals('expenseSubmitted'));
      expect(json['related_expense_id'], equals('exp_789'));

      final parsed = NotificationModel.fromJson(json);
      expect(parsed.id, equals('n_123'));
      expect(parsed.type, equals(NotificationType.expenseSubmitted));
      expect(parsed.isRead, isFalse);
    });
  });

  group('NotificationNotifier State & Deletion Tests', () {
    test('deleteNotification removes item from state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(notificationProvider.notifier);

      notifier.addNotification(
        userId: 'user_1',
        title: 'Alert 1',
        message: 'Message 1',
        fullExplanation: 'Explanation 1',
        type: NotificationType.general,
      );
      notifier.addNotification(
        userId: 'user_1',
        title: 'Alert 2',
        message: 'Message 2',
        fullExplanation: 'Explanation 2',
        type: NotificationType.expenseSubmitted,
      );

      final current = container.read(notificationProvider);
      expect(current.length, equals(2));

      final firstId = current.first.id;
      await notifier.deleteNotification(firstId);

      final updated = container.read(notificationProvider);
      expect(updated.length, equals(1));
      expect(updated.any((n) => n.id == firstId), isFalse);
    });

    test('deleteAll removes all notifications from state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(notificationProvider.notifier);

      notifier.addNotification(
        userId: 'user_1',
        title: 'Alert A',
        message: 'Message A',
        fullExplanation: 'Explanation A',
        type: NotificationType.attendanceReminder,
      );
      notifier.addNotification(
        userId: 'user_1',
        title: 'Alert B',
        message: 'Message B',
        fullExplanation: 'Explanation B',
        type: NotificationType.salaryReady,
      );

      expect(container.read(notificationProvider).length, equals(2));

      await notifier.deleteAll();

      expect(container.read(notificationProvider), isEmpty);
    });

    test('markAllAsRead sets isRead to true for all items', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(notificationProvider.notifier);

      notifier.addNotification(
        userId: 'user_1',
        title: 'Unread 1',
        message: 'Message 1',
        fullExplanation: 'Explanation 1',
        type: NotificationType.general,
      );
      notifier.addNotification(
        userId: 'user_1',
        title: 'Unread 2',
        message: 'Message 2',
        fullExplanation: 'Explanation 2',
        type: NotificationType.budgetWarning,
      );

      expect(container.read(notificationProvider).every((n) => !n.isRead), isTrue);

      notifier.markAllAsRead();

      expect(container.read(notificationProvider).every((n) => n.isRead), isTrue);
    });
  });
}
