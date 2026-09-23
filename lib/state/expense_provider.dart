import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comment_model.dart';
import '../models/expense_model.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';

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
  // Initial expenses reflecting PRD Section 11 & 12 scenarios
  static final List<ExpenseModel> _initialExpenses = [
    // Fahim's expenses on Project 01 (Total: ৳100K, No Receipt: ৳60K = 60% 🔴)
    ExpenseModel(
      id: 'exp_fahim_01',
      employeeId: 'usr_emp_01',
      employeeName: 'Fahim Ahmed',
      projectId: 'proj_01',
      projectName: 'Enterprise Cloud ERP Platform',
      amount: 40000.0,
      officeBenefitAmount: 12000.0, // 30%
      currency: 'BDT',
      categoryId: 'cat_equip',
      categoryName: 'Equipment',
      categoryIcon: 'hardware',
      note: 'AWS GPU cluster and dedicated staging server infrastructure.',
      date: DateTime(2026, 9, 5),
      hasReceipt: true,
      receiptPhotoUrl: 'sample_receipt_invoice.jpg',
      status: ExpenseStatus.approved,
      createdAt: DateTime(2026, 9, 5, 11, 30),
      equipmentDetails: const EquipmentDetails(
        equipmentType: 'AWS Cloud Compute & GPU Cluster',
        isRental: true,
        quantity: 4,
        rentalAmount: 40000.0,
        rentalPeriod: '1 Month',
      ),
    ),
    ExpenseModel(
      id: 'exp_fahim_02',
      employeeId: 'usr_emp_01',
      employeeName: 'Fahim Ahmed',
      projectId: 'proj_01',
      projectName: 'Enterprise Cloud ERP Platform',
      amount: 35000.0,
      officeBenefitAmount: 10500.0, // 30%
      currency: 'BDT',
      categoryId: 'cat_trans',
      categoryName: 'Transportation',
      categoryIcon: 'transport',
      note: 'Client onsite technical sprint planning & team commute.',
      date: DateTime(2026, 9, 12),
      hasReceipt: false, // 🔴 No Receipt
      status: ExpenseStatus.pending,
      justificationStatus: JustificationStatus.required,
      createdAt: DateTime(2026, 9, 12, 18, 45),
      transportationDetails: const TransportationDetails(
        transportationType: TransportationType.cng,
        fromLocation: 'Tech HQ',
        toLocation: 'Client Corporate Tower',
        distanceKm: 45.0,
        fuelCost: 20000.0,
        otherTransportCost: 15000.0,
      ),
    ),
    ExpenseModel(
      id: 'exp_fahim_03',
      employeeId: 'usr_emp_01',
      employeeName: 'Fahim Ahmed',
      projectId: 'proj_01',
      projectName: 'Enterprise Cloud ERP Platform',
      amount: 25000.0,
      officeBenefitAmount: 7500.0, // 30%
      currency: 'BDT',
      categoryId: 'cat_food',
      categoryName: 'Food',
      categoryIcon: 'meal',
      note: 'Dev team sprint release milestone dinner & refreshments.',
      date: DateTime(2026, 9, 14),
      hasReceipt: false, // 🔴 No Receipt
      status: ExpenseStatus.pending,
      justificationStatus: JustificationStatus.required,
      createdAt: DateTime(2026, 9, 14, 21, 15),
      foodDetails: const FoodDetails(
        location: 'Tech Hub Cafeteria',
        attendees: 'Fahim, 7 Fullstack Engineers',
        numberOfPeople: 8,
        mealType: 'Sprint Dinner',
        exceedsFoodAllowance: false,
      ),
    ),

    // Project 02: Sarah & Rahim (Total: ৳80K, No Receipt: ৳20K = 25% 🟢)
    ExpenseModel(
      id: 'exp_04',
      employeeId: 'usr_mgr_01',
      employeeName: 'Sarah Jenkins',
      projectId: 'proj_02',
      projectName: 'Fintech Mobile Banking App (iOS & Android)',
      amount: 60000.0,
      officeBenefitAmount: 12000.0, // 20%
      currency: 'BDT',
      categoryId: 'cat_accomm',
      categoryName: 'Accommodation',
      categoryIcon: 'hotel',
      note: 'Client onsite technical architecture workshop and team accommodation.',
      date: DateTime(2026, 9, 10),
      hasReceipt: true,
      receiptPhotoUrl: 'sample_receipt_invoice.jpg',
      status: ExpenseStatus.approved,
      createdAt: DateTime(2026, 9, 10, 14, 00),
      accommodationDetails: const AccommodationDetails(
        hotelName: 'Tech Residency Suites',
        location: 'Gulshan-2, Dhaka',
        guests: 'Sarah, 3 Lead Engineers',
        numberOfNights: 4,
        ratePerNight: 15000.0,
      ),
    ),
    ExpenseModel(
      id: 'exp_05',
      employeeId: 'usr_mgr_01',
      employeeName: 'Sarah Jenkins',
      projectId: 'proj_02',
      projectName: 'Fintech Mobile Banking App (iOS & Android)',
      amount: 20000.0,
      officeBenefitAmount: 4000.0, // 20%
      currency: 'BDT',
      categoryId: 'cat_trans',
      categoryName: 'Transportation',
      categoryIcon: 'transport',
      note: 'Emergency ride-hail transport for night deployment engineering team.',
      date: DateTime(2026, 9, 13),
      hasReceipt: false, // 25% ratio overall on Project 02
      status: ExpenseStatus.approved,
      justificationStatus: JustificationStatus.approved,
      justificationReason: 'Late night server deployment transport',
      justificationComment: 'Emergency transport after core banking integration release.',
      justificationReviewedBy: 'David Chen',
      justificationReviewedAt: DateTime(2026, 9, 14, 10, 00),
      createdAt: DateTime(2026, 9, 13, 23, 30),
      transportationDetails: const TransportationDetails(
        transportationType: TransportationType.cng,
        fromLocation: 'Server Center',
        toLocation: 'Engineer Residencies',
        distanceKm: 28.0,
      ),
    ),

    // Project 03: Karim (Total: ৳120K, No Receipt: ৳70K = 58.3% 🔴 Review)
    ExpenseModel(
      id: 'exp_06',
      employeeId: 'usr_emp_03',
      employeeName: 'Karim Ullah',
      projectId: 'proj_03',
      projectName: 'AI-Powered Telehealth Diagnostic Portal',
      amount: 50000.0,
      officeBenefitAmount: 15000.0, // 30%
      currency: 'BDT',
      categoryId: 'cat_office',
      categoryName: 'Office Cost',
      categoryIcon: 'office',
      note: 'HIPAA compliance security certification & dev team tooling licenses.',
      date: DateTime(2026, 8, 25),
      hasReceipt: true,
      receiptPhotoUrl: 'sample_receipt_invoice.jpg',
      status: ExpenseStatus.approved,
      createdAt: DateTime(2026, 8, 25, 16, 00),
      officeCostDetails: const OfficeCostDetails(subCategory: 'Software Licenses'),
    ),
    ExpenseModel(
      id: 'exp_07',
      employeeId: 'usr_emp_03',
      employeeName: 'Karim Ullah',
      projectId: 'proj_03',
      projectName: 'AI-Powered Telehealth Diagnostic Portal',
      amount: 70000.0,
      officeBenefitAmount: 21000.0, // 30%
      currency: 'BDT',
      categoryId: 'cat_trans',
      categoryName: 'Transportation',
      categoryIcon: 'transport',
      note: 'Hospital partner integration site visits and doctor onboarding travel.',
      date: DateTime(2026, 9, 8),
      hasReceipt: false, // 🔴 No Receipt
      status: ExpenseStatus.pending,
      justificationStatus: JustificationStatus.submitted,
      justificationReason: 'Local transport receipts unavailable from ride drivers',
      justificationComment: 'Multiple hospital visits across 10 days for doctor app pilot.',
      createdAt: DateTime(2026, 9, 8, 19, 00),
      transportationDetails: const TransportationDetails(
        transportationType: TransportationType.local,
        fromLocation: 'BioHealth Lab',
        toLocation: 'Partner Hospitals',
        distanceKm: 140.0,
      ),
    ),
  ];

  @override
  List<ExpenseModel> build() => _initialExpenses;

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

  /// PRD Section 5, 6, 8, 9, 17: Submit Expense with auto 30% Office Benefit
  void submitExpense({
    required String employeeId,
    required String employeeName,
    required String projectId,
    required String projectName,
    String? taskId,
    String? taskTitle,
    required double amount,
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
  }) {
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

    state = [newExpense, ...state];
  }

  /// PRD Section 13: Justification Workflow
  void submitJustification({
    required String expenseId,
    required String reason,
    required String comment,
    String? attachmentUrl,
  }) {
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
  }

  void approveJustification({
    required String expenseId,
    required String reviewerName,
    String? reviewComment,
  }) {
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
  }

  void rejectJustification({
    required String expenseId,
    required String reviewerName,
    required String reason,
  }) {
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
  }

  void requestClarification({
    required String expenseId,
    required String reviewerName,
    required String note,
  }) {
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
  }

  void approveExpense(String id) {
    state = [
      for (final exp in state)
        if (exp.id == id)
          exp.copyWith(status: ExpenseStatus.approved, rejectionReason: null)
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

  void rejectExpense(String id, String reason) {
    state = [
      for (final exp in state)
        if (exp.id == id)
          exp.copyWith(status: ExpenseStatus.rejected, rejectionReason: reason)
        else
          exp,
    ];
  }

  void withdrawExpense(String id) {
    state = state.where((exp) => !(exp.id == id && exp.status == ExpenseStatus.pending)).toList();
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

final expenseProvider =
    NotifierProvider<ExpenseNotifier, List<ExpenseModel>>(ExpenseNotifier.new);
