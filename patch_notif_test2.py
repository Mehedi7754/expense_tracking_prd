with open('test/notification_feature_test.dart', 'r') as f:
    content = f.read()

old_block = """      // Verify individual delete button works
      final deleteBtn = find.byTooltip('Delete');
      expect(deleteBtn, findsOneWidget);

      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Card is removed
      expect(find.text('New Expense Submitted'), findsNothing);
      expect(find.text('No Notifications'), findsOneWidget);"""

new_block = """      // Verify individual delete button works (close_rounded icon)
      final deleteBtn = find.byIcon(Icons.close_rounded);
      expect(deleteBtn, findsOneWidget);

      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Card is removed
      expect(find.text('New Expense Submitted'), findsNothing);
      expect(find.text('No Notifications'), findsOneWidget);"""

content = content.replace(old_block, new_block)

with open('test/notification_feature_test.dart', 'w') as f:
    f.write(content)
print("Updated test/notification_feature_test.dart")
