import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/comment_model.dart';
import '../models/expense_model.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import '../repositories/expense_repository.dart';

const String _kCustomExpensesKey = 'gw_custom_expenses_cache';

bool _isTestEnvironment() {
  if (kIsWeb) return false;
  return Platform.environment.containsKey('FLUTTER_TEST');
}

class MemberReceiptSummary {
  final String memberId;
  final String memberName;
  final String projectId;
  final String projectName;
  final double totalClaimed;
  final double unreceiptedAmount;
  final double unreceiptedRatio; // e.g. 60.0 for 60%
  final bool isExceedingThreshold;
  final int unreceiptedCount;

  const MemberReceiptSummary({
    required this.memberId,
    required this.memberName,
    required this.projectId,
    required this.projectName,
    required this.totalClaimed,
    required this.unreceiptedAmount,
    required this.unreceiptedRatio,
    required this.isExceedingThreshold,
    required this.unreceiptedCount,
  });
}

class ExpenseNotifier extends Notifier<List<ExpenseModel>> {
  static bool isDummyExpense(ExpenseModel e) {
    const dummyIds = {
      'exp_fahim_01',
      'exp_fahim_02',
      'exp_sarah_01',
      'exp_sarah_02',
      'exp_karim_01',
      'exp_michael_01',
      'exp_fahim_03',
    };
    const dummyNames = {'Fahim Ahmed', 'Sarah Jenkins', 'Karim Ullah', 'Michael Chang', 'Eleanor Vance'};
    const dummyProjects = {
      'proj_01', 'proj_02', 'proj_03', 'proj_04', 'proj_05',
      'Enterprise Cloud ERP Platform',
      'Smart Healthcare IoT System',
      'AI-Powered Logistics Engine',
      'Solar Microgrid Power Hub',
      'Financial Compliance Audit Suite',
    };
    return dummyIds.contains(e.id) ||
        dummyNames.contains(e.employeeName) ||
        dummyProjects.contains(e.projectId) ||
        dummyProjects.contains(e.projectName);
  }

  @override
  List<ExpenseModel> build() {
    _loadCachedExpenses();
    return const [];
  }

  Future<void> _loadCachedExpenses() async {
    if (_isTestEnvironment()) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_kCustomExpensesKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        final customExpenses = decoded
            .whereType<Map<String, dynamic>>()
            .map(ExpenseModel.fromJson)
            .where((e) => !isDummyExpense(e))
            .toList();

        state = customExpenses;
        await prefs.setString(
          _kCustomExpensesKey,
          jsonEncode(customExpenses.map((e) => e.toJson()).toList()),
        );
        debugPrint('[ExpenseNotifier] Restored ${customExpenses.length} real expenses from local cache');
      } else {
        state = const [];
      }
    } catch (e) {
      debugPrint('[ExpenseNotifier] Error loading cached expenses: $e');
      state = const [];
    }
  }

  Future<void> _persistExpenses() async {
    if (_isTestEnvironment()) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final realExpenses = state.where((e) => !isDummyExpense(e)).toList();
      final jsonList = realExpenses.map((e) => e.toJson()).toList();
      await prefs.setString(_kCustomExpensesKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[ExpenseNotifier] Error persisting expenses: $e');
    }
  }

  Future<void> fetchExpenses({
    String? projectId,
    String? employeeId,
    String? status,
  }) async {
    try {
      final repo = ref.read(expenseRepositoryProvider);
      final remoteExpenses = await repo.getExpenses(
        projectId: projectId,
        employeeId: employeeId,
        status: status,
      );
      final validRemote = remoteExpenses.where((e) => !isDummyExpense(e)).toList();
      if (validRemote.isNotEmpty) {
        final remoteIds = validRemote.map((e) => e.id).toSet();
        final localOnly = state.where((e) => !isDummyExpense(e) && !remoteIds.contains(e.id)).toList();
        state = [...validRemote, ...localOnly];
        await _persistExpenses();
        debugPrint('[ExpenseNotifier] Synchronized ${validRemote.length} real expenses from backend');
      }
    } catch (e) {
      debugPrint('[ExpenseNotifier] Offline: keeping cached expenses: $e');
    }
  }

  void setExpenses(List<ExpenseModel> expenses) {
    state = expenses;
    _persistExpenses();
  }

  /// PRD Section 1 & 17: Filter expenses for specific user
  List<ExpenseModel> getExpensesForUser(UserModel? user) {
    if (user == null) return [];
    if (user.role == UserRole.mainAdmin || user.role == UserRole.finance) {
      return state;
    }
    if (user.role == UserRole.projectManager) {
      // Manager sees expenses for assigned projects
      return state.where((e) => user.assignedProjectIds.contains(e.projectId)).toList();
    }
    // Project Member & Viewer see only their own expenses or assigned project
    return state.where((e) => e.employeeId == user.id || user.assignedProjectIds.contains(e.projectId)).toList();
  }

  /// PRD Section 11 & 12: Dual Indicator Monitoring
  /// Returns {totalClaimed, unreceiptedAmount, unreceiptedRatio}
  Map<String, double> getReceiptMetrics({String? memberId, String? projectId}) {
    var filtered = state;
    if (memberId != null) {
      filtered = filtered.where((e) => e.employeeId == memberId).toList();
    }
    if (projectId != null) {
      filtered = filtered.where((e) => e.projectId == projectId).toList();
    }

    final totalClaimed = filtered.fold<double>(0.0, (sum, e) => sum + e.amount);
    final unreceiptedAmount = filtered
        .where((e) => !e.hasReceipt)
        .fold<double>(0.0, (sum, e) => sum + e.amount);
    final ratio = totalClaimed > 0 ? (unreceiptedAmount / totalClaimed) * 100 : 0.0;

    return {
      'totalClaimed': totalClaimed,
      'unreceiptedAmount': unreceiptedAmount,
      'unreceiptedRatio': ratio,
    };
  }

  /// PRD Section 11: Admin dashboard list of members requiring justification (> threshold, default 50%)
  List<MemberReceiptSummary> getMembersRequiringJustification({double redFlagThreshold = 50.0}) {
    final Map<String, List<ExpenseModel>> grouped = {};
    for (final e in state) {
      final key = '${e.employeeId}_${e.projectId}';
      grouped.putIfAbsent(key, () => []).add(e);
    }

    final List<MemberReceiptSummary> summaries = [];
    for (final entry in grouped.entries) {
      final list = entry.value;
      if (list.isEmpty) continue;
      final first = list.first;
      final total = list.fold<double>(0.0, (sum, e) => sum + e.amount);
      final noReceipt = list.where((e) => !e.hasReceipt).fold<double>(0.0, (sum, e) => sum + e.amount);
      final ratio = total > 0 ? (noReceipt / total) * 100 : 0.0;
      final unreceiptedCount = list.where((e) => !e.hasReceipt).length;

      summaries.add(MemberReceiptSummary(
        memberId: first.employeeId,
        memberName: first.employeeName,
        projectId: first.projectId,
        projectName: first.projectName,
        totalClaimed: total,
        unreceiptedAmount: noReceipt,
        unreceiptedRatio: ratio,
        isExceedingThreshold: ratio >= redFlagThreshold,
        unreceiptedCount: unreceiptedCount,
      ));
    }

    return summaries;
  }

  /// PRD Section 5, 6, 8, 9, 17: Submit Expense with auto 30% Office Benefit and Tax calculation
  Future<ExpenseModel> submitExpense({
    required String employeeId,
    required String employeeName,
    required String projectId,
    required String projectName,
    String? taskId,
    String? taskTitle,
    required double amount,
    double? baseCost,
    double taxRate = 0.0,
    double? taxAmount,
    double officeBenefitRate = 0.30, // PRD Section 9: 30% auto calculated
    String currency = 'BDT',
    required String categoryId,
    required String categoryName,
    required String categoryIcon,
    required String note,
    required DateTime date,
    required bool hasReceipt,
    String? receiptPhotoUrl,
    EquipmentDetails? equipmentDetails,
    TransportationDetails? transportationDetails,
    FoodDetails? foodDetails,
    AccommodationDetails? accommodationDetails,
    OfficeCostDetails? officeCostDetails,
  }) async {
    final officeBenefit = amount * officeBenefitRate;
    final newExpense = ExpenseModel(
      id: 'exp_${DateTime.now().microsecondsSinceEpoch}',
      employeeId: employeeId,
      employeeName: employeeName,
      projectId: projectId,
      projectName: projectName,
      taskId: taskId,
      taskTitle: taskTitle,
      amount: amount,
      baseCost: baseCost,
      taxRate: taxRate,
      taxAmount: taxAmount,
      officeBenefitAmount: officeBenefit,
      currency: currency,
      categoryId: categoryId,
      categoryName: categoryName,
      categoryIcon: categoryIcon,
      note: note,
      date: date,
      hasReceipt: hasReceipt,
      receiptPhotoUrl: receiptPhotoUrl,
      status: ExpenseStatus.pending,
      justificationStatus: hasReceipt ? JustificationStatus.none : JustificationStatus.required,
      createdAt: DateTime.now(),
      equipmentDetails: equipmentDetails,
      transportationDetails: transportationDetails,
      foodDetails: foodDetails,
      accommodationDetails: accommodationDetails,
      officeCostDetails: officeCostDetails,
    );

    // Optimistic local update & instant persistence so it's NEVER lost on restart
    state = [newExpense, ...state];
    await _persistExpenses();

    try {
      final repo = ref.read(expenseRepositoryProvider);
      final saved = await repo.createExpense(newExpense);
      state = [
        for (final exp in state)
          if (exp.id == newExpense.id) saved else exp,
      ];
      await _persistExpenses();
      return saved;
    } catch (e) {
      debugPrint('[ExpenseNotifier] Error submitting expense to backend: $e. Retained in local storage.');
      return newExpense;
    }
  }

  /// PRD Section 13: Justification Workflow
  Future<void> submitJustification({
    required String expenseId,
    required String reason,
    required String comment,
    String? attachmentUrl,
  }) async {
    state = [
      for (final exp in state)
        if (exp.id == expenseId)
          exp.copyWith(
            justificationStatus: JustificationStatus.submitted,
            justificationReason: reason,
            justificationComment: comment,
            justificationAttachmentUrl: attachmentUrl,
          )
        else
          exp,
    ];
    await _persistExpenses();

    try {
      final repo = ref.read(expenseRepositoryProvider);
      await repo.submitJustification(
        expenseId,
        reason: reason,
        comment: comment,
        attachmentUrl: attachmentUrl,
      );
    } catch (_) {
      // Offline fallback
    }
  }

  Future<void> approveJustification({
    required String expenseId,
    required String reviewerName,
    String? reviewComment,
  }) async {
    state = [
      for (final exp in state)
        if (exp.id == expenseId)
          exp.copyWith(
            justificationStatus: JustificationStatus.approved,
            justificationReviewedBy: reviewerName,
            justificationReviewComment: reviewComment ?? 'Justification approved by management.',
            justificationReviewedAt: DateTime.now(),
          )
        else
          exp,
    ];
    await _persistExpenses();

    try {
      final repo = ref.read(expenseRepositoryProvider);
      await repo.reviewJustification(
        expenseId,
        status: JustificationStatus.approved,
        reviewComment: reviewComment,
      );
    } catch (_) {
      // Offline fallback
    }
  }

  Future<void> rejectJustification({
    required String expenseId,
    required String reviewerName,
    required String reason,
  }) async {
    state = [
      for (final exp in state)
        if (exp.id == expenseId)
          exp.copyWith(
            justificationStatus: JustificationStatus.rejected,
            justificationReviewedBy: reviewerName,
            justificationReviewComment: reason,
            justificationReviewedAt: DateTime.now(),
          )
        else
          exp,
    ];
    await _persistExpenses();

    try {
      final repo = ref.read(expenseRepositoryProvider);
      await repo.reviewJustification(
        expenseId,
        status: JustificationStatus.rejected,
        reviewComment: reason,
      );
    } catch (_) {
      // Offline fallback
    }
  }

  Future<void> requestClarification({
    required String expenseId,
    required String reviewerName,
    required String note,
  }) async {
    state = [
      for (final exp in state)
        if (exp.id == expenseId)
          exp.copyWith(
            justificationStatus: JustificationStatus.clarificationRequested,
            justificationReviewedBy: reviewerName,
            justificationReviewComment: note,
            justificationReviewedAt: DateTime.now(),
          )
        else
          exp,
    ];
    await _persistExpenses();

    try {
      final repo = ref.read(expenseRepositoryProvider);
      await repo.reviewJustification(
        expenseId,
        status: JustificationStatus.clarificationRequested,
        reviewComment: note,
      );
    } catch (_) {
      // Offline fallback
    }
  }

  Future<void> editExpense({
    required String id,
    required String projectId,
    required String projectName,
    String? taskId,
    String? taskTitle,
    required double amount,
    double? baseCost,
    double taxRate = 0.0,
    double? taxAmount,
    required String currency,
    required String categoryId,
    required String categoryName,
    required String categoryIcon,
    required String note,
    required DateTime date,
    String? receiptPhotoUrl,
  }) async {
    state = [
      for (final exp in state)
        if (exp.id == id && exp.status == ExpenseStatus.pending)
          exp.copyWith(
            projectId: projectId,
            projectName: projectName,
            taskId: taskId,
            taskTitle: taskTitle,
            amount: amount,
            baseCost: baseCost ?? (taxAmount != null && taxAmount > 0 ? (amount - taxAmount) : amount),
            taxRate: taxRate,
            taxAmount: taxAmount ?? (baseCost != null && taxRate > 0 ? (baseCost * (taxRate / 100.0)) : 0.0),
            officeBenefitAmount: amount * 0.30,
            currency: currency,
            categoryId: categoryId,
            categoryName: categoryName,
            categoryIcon: categoryIcon,
            note: note,
            date: date,
            hasReceipt: receiptPhotoUrl != null && receiptPhotoUrl.isNotEmpty,
            receiptPhotoUrl: receiptPhotoUrl,
          )
        else
          exp,
    ];
    await _persistExpenses();

    final updated = state.firstWhere((e) => e.id == id);
    try {
      final repo = ref.read(expenseRepositoryProvider);
      await repo.updateExpense(updated);
    } catch (_) {
      // Offline fallback
    }
  }

  Future<void> approveExpense(String id) async {
    state = [
      for (final exp in state)
        if (exp.id == id)
          exp.copyWith(status: ExpenseStatus.approved, rejectionReason: null)
        else
          exp,
    ];
    await _persistExpenses();

    try {
      final repo = ref.read(expenseRepositoryProvider);
      await repo.updateStatus(id, ExpenseStatus.approved);
    } catch (_) {
      // Offline fallback
    }
  }

  Future<void> batchApprove(List<String> ids) async {
    state = [
      for (final exp in state)
        if (ids.contains(exp.id))
          exp.copyWith(status: ExpenseStatus.approved, rejectionReason: null)
        else
          exp,
    ];
    await _persistExpenses();

    try {
      final repo = ref.read(expenseRepositoryProvider);
      for (final id in ids) {
        await repo.updateStatus(id, ExpenseStatus.approved);
      }
    } catch (_) {
      // Offline fallback
    }
  }

  Future<void> batchReject(List<String> ids, String reason) async {
    state = [
      for (final exp in state)
        if (ids.contains(exp.id))
          exp.copyWith(status: ExpenseStatus.rejected, rejectionReason: reason)
        else
          exp,
    ];
    await _persistExpenses();

    try {
      final repo = ref.read(expenseRepositoryProvider);
      for (final id in ids) {
        await repo.updateStatus(id, ExpenseStatus.rejected, rejectionReason: reason);
      }
    } catch (_) {
      // Offline fallback
    }
  }

  Future<void> rejectExpense(String id, String reason) async {
    state = [
      for (final exp in state)
        if (exp.id == id)
          exp.copyWith(status: ExpenseStatus.rejected, rejectionReason: reason)
        else
          exp,
    ];
    await _persistExpenses();

    try {
      final repo = ref.read(expenseRepositoryProvider);
      await repo.updateStatus(id, ExpenseStatus.rejected, rejectionReason: reason);
    } catch (_) {
      // Offline fallback
    }
  }

  void withdrawExpense(String id) {
    state = state.where((exp) => !(exp.id == id && exp.status == ExpenseStatus.pending)).toList();
    _persistExpenses();
  }

  Future<void> addComment({
    required String expenseId,
    required String text,
    required String authorId,
    required String authorName,
    required UserRole authorRole,
  }) async {
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
    await _persistExpenses();

    try {
      final repo = ref.read(expenseRepositoryProvider);
      await repo.addComment(expenseId, newComment);
    } catch (_) {
      // Offline fallback
    }
  }
}

final expenseProvider =
    NotifierProvider<ExpenseNotifier, List<ExpenseModel>>(ExpenseNotifier.new);
