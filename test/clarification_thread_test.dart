import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracking_prd/models/comment_model.dart';
import 'package:expense_tracking_prd/models/user_role.dart';
import 'package:expense_tracking_prd/core/widgets/comment_thread_widget.dart';

void main() {
  group('Clarification Thread Comment Parsing & Display Tests', () {
    test('CommentModel parses accurately from backend json with "comment" and "comment_text" keys', () {
      final backendJsonWithComment = {
        'id': 'c_101',
        'expense_id': 'exp_999',
        'author_id': 'usr_456',
        'author_name': 'Reviewer Jane',
        'author_role': 'project_manager',
        'comment': 'Please provide the vendor invoice for verification.',
        'created_at': '2026-11-15T12:00:00Z',
      };

      final model1 = CommentModel.fromJson(backendJsonWithComment);
      expect(model1.id, 'c_101');
      expect(model1.text, 'Please provide the vendor invoice for verification.');
      expect(model1.authorName, 'Reviewer Jane');
      expect(model1.authorRole, UserRole.projectManager);

      final backendJsonWithCommentText = {
        'id': 'c_102',
        'expense_id': 'exp_999',
        'author_id': 'usr_123',
        'author_name': 'Employee John',
        'author_role': 'project_member',
        'comment_text': 'Here is the clarification note.',
        'created_at': '2026-11-15T12:05:00Z',
      };

      final model2 = CommentModel.fromJson(backendJsonWithCommentText);
      expect(model2.id, 'c_102');
      expect(model2.text, 'Here is the clarification note.');
      expect(model2.authorName, 'Employee John');

      final serialized = model1.toJson();
      expect(serialized['comment'], 'Please provide the vendor invoice for verification.');
      expect(serialized['comment_text'], 'Please provide the vendor invoice for verification.');
      expect(serialized['text'], 'Please provide the vendor invoice for verification.');
    });

    testWidgets('CommentThreadWidget renders comment messages visibly and allows typing reply', (tester) async {
      final comments = [
        CommentModel(
          id: 'c_1',
          expenseId: 'exp_1',
          authorId: 'u_1',
          authorName: 'Admin Sarah',
          authorRole: UserRole.mainAdmin,
          text: 'Can you confirm this hotel stay was authorized?',
          timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
        ),
        CommentModel(
          id: 'c_2',
          expenseId: 'exp_1',
          authorId: 'u_2',
          authorName: 'John Field',
          authorRole: UserRole.projectMember,
          text: 'Yes, approval email is attached to the justification.',
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      ];

      String? submittedText;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CommentThreadWidget(
                comments: comments,
                isReadOnly: false,
                onAddComment: (msg) {
                  submittedText = msg;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the section title and counter
      expect(find.text('Clarification Thread'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      // Verify both comment messages are visibly rendered
      expect(find.text('Can you confirm this hotel stay was authorized?'), findsOneWidget);
      expect(find.text('Yes, approval email is attached to the justification.'), findsOneWidget);
      expect(find.text('Admin Sarah'), findsOneWidget);
      expect(find.text('John Field'), findsOneWidget);

      // Enter a new comment and submit
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      await tester.enterText(textField, 'Verified and acknowledged.');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(submittedText, 'Verified and acknowledged.');
    });
  });
}
