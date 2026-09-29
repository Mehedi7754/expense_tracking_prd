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

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    final roleStr = (json['author_role'] ?? json['authorRole'] ?? 'project_member').toString();
    return CommentModel(
      id: (json['id'] ?? '').toString(),
      expenseId: (json['expense_id'] ?? json['expenseId'] ?? '').toString(),
      authorId: (json['author_id'] ?? json['authorId'] ?? '').toString(),
      authorName: (json['author_name'] ?? json['authorName'] ?? '').toString(),
      authorRole: UserRole.fromString(roleStr),
      text: (json['text'] ?? json['comment_text'] ?? '').toString(),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : (json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
              : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'expense_id': expenseId,
      'author_id': authorId,
      'author_name': authorName,
      'author_role': authorRole.name,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
