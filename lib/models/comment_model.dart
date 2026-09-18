import 'user_role.dart';

class CommentModel {
  final String id;
  final String expenseId;
  final String authorId;
  final String authorName;
  final UserRole authorRole;
  final String text;
  final DateTime timestamp;

  const CommentModel({
    required this.id,
    required this.expenseId,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.text,
    required this.timestamp,
  });
}
