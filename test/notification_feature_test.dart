import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_tracking_prd/models/notification_model.dart';
import 'package:expense_tracking_prd/screens/notifications/notifications_screen.dart';
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

  group('NotificationsScreen Widget Tests', () {
    testWidgets('Renders EmptyStateWidget when no notifications exist', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: NotificationsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('No Notifications'), findsOneWidget);
      expect(find.text('You are all caught up! There are no alerts for your account right now.'), findsOneWidget);
    });

    testWidgets('Renders notification cards with delete button and unread indicator', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(notificationProvider.notifier);
      notifier.addNotification(
        userId: '',
        title: 'New Expense Submitted',
        message: 'A claim for Travel was submitted',
        fullExplanation: 'Full claim info',
        type: NotificationType.expenseSubmitted,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: NotificationsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('New Expense Submitted'), findsOneWidget);
      expect(find.text('A claim for Travel was submitted'), findsOneWidget);
      expect(find.text('Mark All Read'), findsOneWidget);
      expect(find.byTooltip('Delete All'), findsOneWidget);

      // Verify individual delete button works
      final deleteBtn = find.byTooltip('Delete');
      expect(deleteBtn, findsOneWidget);

      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Card is removed
      expect(find.text('New Expense Submitted'), findsNothing);
      expect(find.text('No Notifications'), findsOneWidget);
    });

    testWidgets('Delete All button shows confirmation dialog and cancels or deletes', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(notificationProvider.notifier);
      notifier.addNotification(
        userId: '',
        title: 'Alert 1',
        message: 'Message 1',
        fullExplanation: 'Exp 1',
        type: NotificationType.general,
      );
      notifier.addNotification(
        userId: '',
        title: 'Alert 2',
        message: 'Message 2',
        fullExplanation: 'Exp 2',
        type: NotificationType.budgetWarning,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: NotificationsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alert 1'), findsOneWidget);
      expect(find.text('Alert 2'), findsOneWidget);

      // Tap Delete All
      await tester.tap(find.byTooltip('Delete All'));
      await tester.pumpAndSettle();

      // Dialog appears
      expect(find.text('Delete All Notifications'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Cancel first
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Alert 1'), findsOneWidget);

      // Tap Delete All again and confirm
      await tester.tap(find.byTooltip('Delete All'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Delete All'));
      await tester.pumpAndSettle();

      expect(find.text('No Notifications'), findsOneWidget);
    });
  });
}

