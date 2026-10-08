with open('test/notification_feature_test.dart', 'r') as f:
    content = f.read()

old_block = """      expect(find.text('New Expense Submitted'), findsOneWidget);
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
    });"""

new_block = """      expect(find.text('New Expense Submitted'), findsOneWidget);
      expect(find.text('A claim for Travel was submitted'), findsOneWidget);
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

    testWidgets('Delete All button permanently deletes all notifications and shows SnackBar', (tester) async {
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

      expect(find.text('No Notifications'), findsOneWidget);
      expect(find.text('All notifications permanently deleted'), findsOneWidget);
    });"""

if old_block in content:
    content = content.replace(old_block, new_block)
    with open('test/notification_feature_test.dart', 'w') as f:
        f.write(content)
    print("Patched notification test successfully")
else:
    print("Old block not found in test file")
