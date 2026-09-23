import 'client_model.dart';

class RevenueEntry {
  final String id;
  final String projectId;
  final double amount;
  final DateTime date;
  final String note;
  final String createdBy;

  const RevenueEntry({
    required this.id,
    required this.projectId,
    required this.amount,
    required this.date,
    required this.note,
    required this.createdBy,
  });
}

enum ProjectStatus {
  proposal,
  approved,
  ongoing,
  completed,
  suspended,
  cancelled;

  String get displayName {
    switch (this) {
      case ProjectStatus.proposal:
        return 'Proposal';
      case ProjectStatus.approved:
        return 'Approved';
      case ProjectStatus.ongoing:
        return 'Ongoing';
      case ProjectStatus.completed:
        return 'Completed';
      case ProjectStatus.suspended:
        return 'Suspended';
      case ProjectStatus.cancelled:
        return 'Cancelled';
    }
  }

  static ProjectStatus fromString(String val) {
    switch (val.toLowerCase().replaceAll(' ', '').replaceAll('-', '')) {
      case 'proposal':
        return ProjectStatus.proposal;
      case 'approved':
        return ProjectStatus.approved;
      case 'completed':
        return ProjectStatus.completed;
      case 'suspended':
      case 'onhold':
        return ProjectStatus.suspended;
      case 'cancelled':
        return ProjectStatus.cancelled;
      case 'ongoing':
      case 'active':
      default:
        return ProjectStatus.ongoing;
    }
  }
}

enum AssignmentType {
  directConsultancy,
  subConsultancy,
  government,
  private;

  String get displayName {
    switch (this) {
      case AssignmentType.directConsultancy:
        return 'Direct Consultancy';
      case AssignmentType.subConsultancy:
        return 'Sub-consultancy';
      case AssignmentType.government:
        return 'Government';
      case AssignmentType.private:
        return 'Private';
    }
  }

  static AssignmentType fromString(String val) {
    switch (val.toLowerCase().replaceAll(' ', '').replaceAll('-', '')) {
      case 'subconsultancy':
        return AssignmentType.subConsultancy;
      case 'government':
        return AssignmentType.government;
      case 'private':
        return AssignmentType.private;
      case 'directconsultancy':
      case 'direct':
      default:
        return AssignmentType.directConsultancy;
    }
  }
}

enum TaxStatus {
  included,
  excluded,
  notApplicable;

  String get displayName {
    switch (this) {
      case TaxStatus.included:
        return 'IT-VAT: Included';
      case TaxStatus.excluded:
        return 'IT-VAT: Excluded';
      case TaxStatus.notApplicable:
        return 'IT-VAT: Not Applicable';
    }
  }

  static TaxStatus fromString(String val) {
    switch (val.toLowerCase().replaceAll(' ', '').replaceAll('-', '')) {
      case 'included':
        return TaxStatus.included;
      case 'excluded':
        return TaxStatus.excluded;
      case 'notapplicable':
      case 'na':
      default:
        return TaxStatus.notApplicable;
    }
  }
}

class ProjectFinancialSummary {
  final double contractValue;
  final String taxInfo;
  final double totalRevenue;
  final double directExpenditure;
  final double officeBenefit;
  final double netProjectCost;
  final double profit;
  final double profitMargin;
  final double totalReceivable;
  final double receiptComplianceRate;
  final int teamMembersCount;
  final double budgetVariance;
  final DateTime closedAt;

  const ProjectFinancialSummary({
    required this.contractValue,
    required this.taxInfo,
    required this.totalRevenue,
    required this.directExpenditure,
    required this.officeBenefit,
    required this.netProjectCost,
    required this.profit,
    required this.profitMargin,
    required this.totalReceivable,
    required this.receiptComplianceRate,
    required this.teamMembersCount,
    required this.budgetVariance,
    required this.closedAt,
  });
}

class ProjectModel {
  final String id;
  final String projectId; // Auto-generated e.g. PRJ-2026-001
  final String name;
  final String description;
  final String client;
  final ClientType clientType;
  final AssignmentType assignmentType;
  final double grossProjectValue; // Contract Value in ৳
  final TaxStatus taxStatus;
  final double taxRate; // e.g. 0.10 for 10%
  final double expectedNetRevenue;
  final double advanceReceived;
  final double amountReceived;
  final double amountReceivable;
  final double budget; // Total Budget
  final Map<String, double> categoryBudgets; // Equipment, Transport, Food, Accommodation, Office, Office Benefit
  final double estimatedRemainingCost; // For financial forecast
  final double officeBenefitRate; // Default 0.30
  final DateTime startDate;
  final DateTime endDate;
  final List<String> teamMemberIds;
  final ProjectStatus status;
  final List<RevenueEntry> revenueEntries;
  final bool isClosed;
  final ProjectFinancialSummary? closingSummary;

  const ProjectModel({
    required this.id,
    required this.projectId,
    required this.name,
    required this.description,
    required this.client,
    this.clientType = ClientType.private,
    this.assignmentType = AssignmentType.directConsultancy,
    required this.grossProjectValue,
    this.taxStatus = TaxStatus.included,
    this.taxRate = 0.10,
    required this.expectedNetRevenue,
    this.advanceReceived = 0.0,
    this.amountReceived = 0.0,
    required this.amountReceivable,
    required this.budget,
    this.categoryBudgets = const {},
    this.estimatedRemainingCost = 0.0,
    this.officeBenefitRate = 0.30,
    required this.startDate,
    required this.endDate,
    required this.teamMemberIds,
    this.status = ProjectStatus.ongoing,
    this.revenueEntries = const [],
    this.isClosed = false,
    this.closingSummary,
  });

  // Backward compatibility getter
  double get expectedRevenue => expectedNetRevenue;

  ProjectModel copyWith({
    String? id,
    String? projectId,
    String? name,
    String? description,
    String? client,
    ClientType? clientType,
    AssignmentType? assignmentType,
    double? grossProjectValue,
    TaxStatus? taxStatus,
    double? taxRate,
    double? expectedNetRevenue,
    double? advanceReceived,
    double? amountReceived,
    double? amountReceivable,
    double? budget,
    Map<String, double>? categoryBudgets,
    double? estimatedRemainingCost,
    double? officeBenefitRate,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? teamMemberIds,
    ProjectStatus? status,
    List<RevenueEntry>? revenueEntries,
    bool? isClosed,
    ProjectFinancialSummary? closingSummary,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      description: description ?? this.description,
      client: client ?? this.client,
      clientType: clientType ?? this.clientType,
      assignmentType: assignmentType ?? this.assignmentType,
      grossProjectValue: grossProjectValue ?? this.grossProjectValue,
      taxStatus: taxStatus ?? this.taxStatus,
      taxRate: taxRate ?? this.taxRate,
      expectedNetRevenue: expectedNetRevenue ?? this.expectedNetRevenue,
      advanceReceived: advanceReceived ?? this.advanceReceived,
      amountReceived: amountReceived ?? this.amountReceived,
      amountReceivable: amountReceivable ?? this.amountReceivable,
      budget: budget ?? this.budget,
      categoryBudgets: categoryBudgets ?? this.categoryBudgets,
      estimatedRemainingCost: estimatedRemainingCost ?? this.estimatedRemainingCost,
      officeBenefitRate: officeBenefitRate ?? this.officeBenefitRate,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      teamMemberIds: teamMemberIds ?? this.teamMemberIds,
      status: status ?? this.status,
      revenueEntries: revenueEntries ?? this.revenueEntries,
      isClosed: isClosed ?? this.isClosed,
      closingSummary: closingSummary ?? this.closingSummary,
    );
  }
}
