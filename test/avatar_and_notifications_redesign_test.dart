import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracking_prd/core/widgets/app_avatar.dart';
import 'package:expense_tracking_prd/models/notification_model.dart';
import 'package:expense_tracking_prd/models/user_model.dart';
import 'package:expense_tracking_prd/models/user_role.dart';
import 'package:expense_tracking_prd/screens/notifications/notifications_screen.dart';
import 'package:expense_tracking_prd/state/notification_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserModel Avatar CopyWith Tests', () {
    const user = UserModel(
      id: 'usr_1',
      name: 'Alice Cooper',
      email: 'alice@example.com',
      role: UserRole.projectMember,
      department: 'Engineering',
      avatarUrl: 'https://example.com/avatar.jpg',
    );

    test('copyWith updates avatarUrl to new value', () {
      final updated = user.copyWith(avatarUrl: 'https://example.com/new.jpg');
      expect(updated.avatarUrl, equals('https://example.com/new.jpg'));
    });

    test('copyWith preserves avatarUrl when avatarUrl is null and clearAvatarUrl is false', () {
      final updated = user.copyWith(name: 'Alice Cooper New');
      expect(updated.avatarUrl, equals('https://example.com/avatar.jpg'));
    });

    test('copyWith clears avatarUrl when clearAvatarUrl is true', () {
      final cleared = user.copyWith(clearAvatarUrl: true);
      expect(cleared.avatarUrl, isNull);
    });
  });

  group('AppAvatar Widget Tests', () {
    testWidgets('AppAvatar renders initials when imageUrl is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppAvatar(
              imageUrl: null,
              name: 'John Doe',
              size: 40,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('JD'), findsOneWidget);
    });

    testWidgets('AppAvatar renders single initial for single name', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppAvatar(
              imageUrl: '',
              name: 'Sarah',
              size: 40,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SA'), findsOneWidget);
    });

    testWidgets('AppAvatar gracefully handles base64 Data URI', (tester) async {
      // 1x1 transparent png in base64
      const base64Png =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppAvatar(
              imageUrl: base64Png,
              name: 'Image User',
              size: 50,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Memory image renders without throwing exception
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('AppAvatar gracefully falls back to initials if base64 is corrupt', (tester) async {
      const corruptBase64 = 'data:image/png;base64,invalid_corrupt_data!!!';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppAvatar(
              imageUrl: corruptBase64,
              name: 'Corrupt User',
              size: 50,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CU'), findsOneWidget);
    });

    testWidgets('AppAvatar renders badge if provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppAvatar(
              imageUrl: null,
              name: 'Badge User',
              size: 40,
              badge: Icon(Icons.star, size: 12),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star), findsOneWidget);
    });
  });

  group('NotificationsScreen Redesign Tests', () {
    testWidgets('Category filters switch items properly', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(notificationProvider.notifier);
      // Add expense notification
      notifier.addNotification(
        userId: '',
        title: 'Taxi Receipt Claim',
        message: 'Expense submitted for \$45.00',
        fullExplanation: 'Claim details',
        type: NotificationType.expenseSubmitted,
      );
      // Add project notification
      notifier.addNotification(
        userId: '',
        title: 'Project Assignment',
        message: 'You have been assigned to Project Beta',
        fullExplanation: 'Project details',
        type: NotificationType.projectAssigned,
      );
      // Add attendance notification
      notifier.addNotification(
        userId: '',
        title: 'Late Check-in Logged',
        message: 'Checked in 15 mins past start time',
        fullExplanation: 'Attendance info',
        type: NotificationType.attendanceLate,
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

      // All 3 appear under "All"
      expect(find.text('Taxi Receipt Claim'), findsOneWidget);
      expect(find.text('Project Assignment'), findsOneWidget);
      expect(find.text('Late Check-in Logged'), findsOneWidget);

      // Tap Expenses pill
      await tester.ensureVisible(find.text('Expenses'));
      await tester.tap(find.text('Expenses'));
      await tester.pumpAndSettle();

      expect(find.text('Taxi Receipt Claim'), findsOneWidget);
      expect(find.text('Project Assignment'), findsNothing);
      expect(find.text('Late Check-in Logged'), findsNothing);

      // Tap Projects pill
      await tester.ensureVisible(find.text('Projects'));
      await tester.tap(find.text('Projects'));
      await tester.pumpAndSettle();

      expect(find.text('Taxi Receipt Claim'), findsNothing);
      expect(find.text('Project Assignment'), findsOneWidget);
      expect(find.text('Late Check-in Logged'), findsNothing);

      // Tap Attendance pill
      await tester.ensureVisible(find.text('Attendance'));
      await tester.tap(find.text('Attendance'));
      await tester.pumpAndSettle();

      expect(find.text('Taxi Receipt Claim'), findsNothing);
      expect(find.text('Project Assignment'), findsNothing);
      expect(find.text('Late Check-in Logged'), findsOneWidget);
    });

    testWidgets('Mark all read button updates unread state and count', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(notificationProvider.notifier);
      notifier.addNotification(
        userId: '',
        title: 'Unread Alert 1',
        message: 'Message 1',
        fullExplanation: 'Exp 1',
        type: NotificationType.general,
      );
      notifier.addNotification(
        userId: '',
        title: 'Unread Alert 2',
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

      expect(find.text('Mark all read'), findsOneWidget);
      expect(find.text('2 unread notifications'), findsOneWidget);

      // Tap Mark all read
      await tester.tap(find.text('Mark all read'));
      await tester.pumpAndSettle();

      expect(find.text('All notifications caught up'), findsOneWidget);
      expect(find.text('All notifications marked as read'), findsOneWidget);
    });
  });
}
