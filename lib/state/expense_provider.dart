import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comment_model.dart';
import '../models/expense_model.dart';
import '../models/user_role.dart';

class ExpenseNotifier extends Notifier<List<ExpenseModel>> {
  static final List<ExpenseModel> _initialExpenses = [
    ExpenseModel(
      id: 'exp_01',
      employeeId: 'usr_emp_01',
      employeeName: 'Alex Morgan',
      projectId: 'proj_01',
      projectName: 'Mobile App Modernization',
      taskId: 'tsk_01',
      taskTitle: 'Design System & Token Architecture',
      amount: 145.50,
      currency: 'USD',
      categoryId: 'cat_05',
      categoryName: 'Software & Tools',
      categoryIcon: 'software',
      note: 'Figma Organization annual seat license for Q3.',
      date: DateTime(2026, 9, 10),
      receiptPhotoUrl: 'sample_receipt_invoice.jpg',
      status: ExpenseStatus.approved,
      createdAt: DateTime(2026, 9, 10, 14, 30),
      comments: [
        CommentModel(
          id: 'c_01',
          expenseId: 'exp_01',
          authorId: 'usr_mgr_01',
          authorName: 'Sarah Jenkins',
          authorRole: UserRole.manager,
          text: 'Approved under product tools budget.',
          timestamp: DateTime(2026, 9, 11, 10, 15),
        ),
      ],
    ),
    ExpenseModel(
      id: 'exp_02',
      employeeId: 'usr_emp_01',
      employeeName: 'Alex Morgan',
      projectId: 'proj_01',
      projectName: 'Mobile App Modernization',
      taskId: 'tsk_02',
      taskTitle: 'State Management & GoRouter Wiring',
      amount: 85.00,
      currency: 'USD',
      categoryId: 'cat_02',
      categoryName: 'Meals & Dining',
      categoryIcon: 'meal',
      note: 'Sprint retrospective team working dinner with client engineers.',
      date: DateTime(2026, 9, 15),
      receiptPhotoUrl: 'sample_receipt_invoice.jpg',
      status: ExpenseStatus.pending,
      createdAt: DateTime(2026, 9, 15, 20, 00),
      comments: [
        CommentModel(
          id: 'c_02',
          expenseId: 'exp_02',
          authorId: 'usr_mgr_01',
          authorName: 'Sarah Jenkins',
          authorRole: UserRole.manager,
          text: 'Did the client attendee list include external directors?',
          timestamp: DateTime(2026, 9, 16, 9, 30),
        ),
        CommentModel(
          id: 'c_03',
          expenseId: 'exp_02',
          authorId: 'usr_emp_01',
          authorName: 'Alex Morgan',
          authorRole: UserRole.employee,
          text: 'Yes, 3 engineers from Acme team were present.',
          timestamp: DateTime(2026, 9, 16, 9, 45),
        ),
      ],
    ),
    ExpenseModel(
      id: 'exp_03',
      employeeId: 'usr_emp_01',
      employeeName: 'Alex Morgan',
      projectId: 'proj_02',
      projectName: 'Cloud Infrastructure Migration',
      taskId: 'tsk_03',
      taskTitle: 'Terraform Cluster Provisioning',
      amount: 450.00,
      currency: 'USD',
      categoryId: 'cat_01',
      categoryName: 'Travel & Flights',
      categoryIcon: 'travel',
      note: 'Flight to Chicago datacenter for emergency cluster failover setup.',
      date: DateTime(2026, 9, 12),
      receiptPhotoUrl: 'sample_receipt_invoice.jpg',
      status: ExpenseStatus.pending,
      createdAt: DateTime(2026, 9, 12, 11, 20),
    ),
    ExpenseModel(
      id: 'exp_04',
      employeeId: 'usr_emp_01',
      employeeName: 'Alex Morgan',
      projectId: 'proj_03',
      projectName: 'AI Analytics Pipeline',
      taskId: 'tsk_04',
      taskTitle: 'Model Ingestion & Evaluation Suite',
      amount: 320.00,
      currency: 'USD',
      categoryId: 'cat_04',
      categoryName: 'Hardware & Devices',
      categoryIcon: 'hardware',
      note: 'External GPU development accelerator enclosure.',
      date: DateTime(2026, 9, 5),
      receiptPhotoUrl: null,
      status: ExpenseStatus.rejected,
      rejectionReason: 'Device purchases must go through central procurement rather than expense claims.',
      createdAt: DateTime(2026, 9, 5, 16, 40),
    ),
    ExpenseModel(
      id: 'exp_05',
      employeeId: 'usr_emp_02',
      employeeName: 'Jordan Taylor',
      projectId: 'proj_02',
      projectName: 'Cloud Infrastructure Migration',
      amount: 62.40,
      currency: 'USD',
      categoryId: 'cat_06',
      categoryName: 'Ground Transport & Taxi',
      categoryIcon: 'transport',
      note: 'Taxi to client office for architecture review.',
      date: DateTime(2026, 9, 14),
      receiptPhotoUrl: 'sample_receipt_invoice.jpg',
      status: ExpenseStatus.pending,
      createdAt: DateTime(2026, 9, 14, 18, 10),
    ),
    ExpenseModel(
      id: 'exp_06',
      employeeId: 'usr_emp_03',
      employeeName: 'Maya Patel',
      projectId: 'proj_01',
      projectName: 'Mobile App Modernization',
      amount: 120.00,
      currency: 'USD',
      categoryId: 'cat_07',
      categoryName: 'Office & Supplies',
      categoryIcon: 'office',
      note: 'Whiteboard accessories and design sprint stationery.',
      date: DateTime(2026, 8, 28),
      receiptPhotoUrl: 'sample_receipt_invoice.jpg',
      status: ExpenseStatus.approved,
      createdAt: DateTime(2026, 8, 28, 15, 00),
    ),
  ];

  @override
  List<ExpenseModel> build() => _initialExpenses;

  void submitExpense({
    required String employeeId,
    required String employeeName,
    required String projectId,
    required String projectName,
    String? taskId,
    String? taskTitle,
    required double amount,
    required String currency,
    required String categoryId,
    required String categoryName,
    required String categoryIcon,
    required String note,
    required DateTime date,
    String? receiptPhotoUrl,
  }) {
    final newExpense = ExpenseModel(
      id: 'exp_${DateTime.now().microsecondsSinceEpoch}',
      employeeId: employeeId,
      employeeName: employeeName,
      projectId: projectId,
      projectName: projectName,
      taskId: taskId,
      taskTitle: taskTitle,
      amount: amount,
      currency: currency,
      categoryId: categoryId,
      categoryName: categoryName,
      categoryIcon: categoryIcon,
      note: note,
      date: date,
      receiptPhotoUrl: receiptPhotoUrl,
      status: ExpenseStatus.pending,
      createdAt: DateTime.now(),
    );

    state = [newExpense, ...state];
  }

  void editExpense({
    required String id,
    required String projectId,
    required String projectName,
    String? taskId,
    String? taskTitle,
    required double amount,
    required String currency,
    required String categoryId,
    required String categoryName,
    required String categoryIcon,
    required String note,
    required DateTime date,
    String? receiptPhotoUrl,
  }) {
    state = [
      for (final exp in state)
        if (exp.id == id && exp.status == ExpenseStatus.pending)
          exp.copyWith(
            projectId: projectId,
            projectName: projectName,
            taskId: taskId,
            taskTitle: taskTitle,
            amount: amount,
            currency: currency,
            categoryId: categoryId,
            categoryName: categoryName,
            categoryIcon: categoryIcon,
            note: note,
            date: date,
            receiptPhotoUrl: receiptPhotoUrl,
          )
        else
          exp,
    ];
  }

  void withdrawExpense(String id) {
    state = state.where((exp) => !(exp.id == id && exp.status == ExpenseStatus.pending)).toList();
  }

  void approveExpense(String id) {
    state = [
      for (final exp in state)
        if (exp.id == id)
          exp.copyWith(
            status: ExpenseStatus.approved,
            rejectionReason: null,
          )
        else
          exp,
    ];
  }

  void rejectExpense(String id, String reason) {
    state = [
      for (final exp in state)
        if (exp.id == id)
          exp.copyWith(
            status: ExpenseStatus.rejected,
            rejectionReason: reason,
          )
        else
          exp,
    ];
  }

  void batchApprove(List<String> ids) {
    state = [
      for (final exp in state)
        if (ids.contains(exp.id))
          exp.copyWith(status: ExpenseStatus.approved, rejectionReason: null)
        else
          exp,
    ];
  }

  void batchReject(List<String> ids, String reason) {
    state = [
      for (final exp in state)
        if (ids.contains(exp.id))
          exp.copyWith(status: ExpenseStatus.rejected, rejectionReason: reason)
        else
          exp,
    ];
  }

  void addComment({
    required String expenseId,
    required String text,
    required String authorId,
    required String authorName,
    required UserRole authorRole,
  }) {
    final newComment = CommentModel(
      id: 'c_${DateTime.now().microsecondsSinceEpoch}',
      expenseId: expenseId,
      authorId: authorId,
      authorName: authorName,
      authorRole: authorRole,
      text: text,
      timestamp: DateTime.now(),
    );

    state = [
      for (final exp in state)
        if (exp.id == expenseId)
          exp.copyWith(comments: [...exp.comments, newComment])
        else
          exp,
    ];
  }
}

final expenseProvider = NotifierProvider<ExpenseNotifier, List<ExpenseModel>>(ExpenseNotifier.new);
