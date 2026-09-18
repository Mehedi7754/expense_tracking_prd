import 'comment_model.dart';

enum ExpenseStatus {
  pending,
  approved,
  rejected;

  String get displayName {
    switch (this) {
      case ExpenseStatus.pending:
        return 'Pending';
      case ExpenseStatus.approved:
        return 'Approved';
      case ExpenseStatus.rejected:
        return 'Rejected';
    }
  }
}

class ExpenseModel {
  final String id;
  final String employeeId;
  final String employeeName;
  final String projectId;
  final String projectName;
  final String? taskId;
  final String? taskTitle;
  final double amount;
  final String currency;
  final String categoryId;
  final String categoryName;
  final String categoryIcon;
  final String note;
  final DateTime date;
  final String? receiptPhotoUrl;
  final ExpenseStatus status;
  final String? rejectionReason;
  final List<CommentModel> comments;
  final DateTime createdAt;

  const ExpenseModel({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.projectId,
    required this.projectName,
    this.taskId,
    this.taskTitle,
    required this.amount,
    this.currency = 'USD',
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.note,
    required this.date,
    this.receiptPhotoUrl,
    this.status = ExpenseStatus.pending,
    this.rejectionReason,
    this.comments = const [],
    required this.createdAt,
  });

  ExpenseModel copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    String? projectId,
    String? projectName,
    String? taskId,
    String? taskTitle,
    double? amount,
    String? currency,
    String? categoryId,
    String? categoryName,
    String? categoryIcon,
    String? note,
    DateTime? date,
    String? receiptPhotoUrl,
    ExpenseStatus? status,
    String? rejectionReason,
    List<CommentModel>? comments,
    DateTime? createdAt,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      taskId: taskId ?? this.taskId,
      taskTitle: taskTitle ?? this.taskTitle,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryIcon: categoryIcon ?? this.categoryIcon,
      note: note ?? this.note,
      date: date ?? this.date,
      receiptPhotoUrl: receiptPhotoUrl ?? this.receiptPhotoUrl,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      comments: comments ?? this.comments,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
