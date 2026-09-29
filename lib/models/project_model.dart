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

  factory RevenueEntry.fromJson(Map<String, dynamic> json) {
    return RevenueEntry(
      id: (json['id'] ?? '').toString(),
      projectId: (json['project_id'] ?? json['projectId'] ?? '').toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      note: (json['note'] ?? '').toString(),
      createdBy: (json['created_by'] ?? json['createdBy'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
      'created_by': createdBy,
    };
  }
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
    switch (val.toLowerCase().replaceAll(' ', '').replaceAll('-', '').replaceAll('_', '')) {
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
    switch (val.toLowerCase().replaceAll(' ', '').replaceAll('-', '').replaceAll('_', '')) {
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
    switch (val.toLowerCase().replaceAll(' ', '').replaceAll('-', '').replaceAll('_', '')) {
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

  factory ProjectFinancialSummary.fromJson(Map<String, dynamic> json) {
    return ProjectFinancialSummary(
      contractValue: (json['contract_value'] ?? json['contractValue'] as num?)?.toDouble() ?? 0.0,
      taxInfo: (json['tax_info'] ?? json['taxInfo'] ?? '').toString(),
      totalRevenue: (json['total_revenue'] ?? json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      directExpenditure: (json['direct_expenditure'] ?? json['directExpenditure'] as num?)?.toDouble() ?? 0.0,
      officeBenefit: (json['office_benefit'] ?? json['officeBenefit'] as num?)?.toDouble() ?? 0.0,
      netProjectCost: (json['net_project_cost'] ?? json['netProjectCost'] as num?)?.toDouble() ?? 0.0,
      profit: (json['profit'] as num?)?.toDouble() ?? 0.0,
      profitMargin: (json['profit_margin'] ?? json['profitMargin'] as num?)?.toDouble() ?? 0.0,
      totalReceivable: (json['total_receivable'] ?? json['totalReceivable'] as num?)?.toDouble() ?? 0.0,
      receiptComplianceRate: (json['receipt_compliance_rate'] ?? json['receiptComplianceRate'] as num?)?.toDouble() ?? 0.0,
      teamMembersCount: (json['team_members_count'] ?? json['teamMembersCount'] as num?)?.toInt() ?? 0,
      budgetVariance: (json['budget_variance'] ?? json['budgetVariance'] as num?)?.toDouble() ?? 0.0,
      closedAt: json['closed_at'] != null
          ? DateTime.tryParse(json['closed_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'contract_value': contractValue,
      'tax_info': taxInfo,
      'total_revenue': totalRevenue,
      'direct_expenditure': directExpenditure,
      'office_benefit': officeBenefit,
      'net_project_cost': netProjectCost,
      'profit': profit,
      'profit_margin': profitMargin,
      'total_receivable': totalReceivable,
      'receipt_compliance_rate': receiptComplianceRate,
      'team_members_count': teamMembersCount,
      'budget_variance': budgetVariance,
      'closed_at': closedAt.toIso8601String(),
    };
  }
}

class ProjectModel {
  final String id;
  final String projectId; // Auto-generated code e.g. PRJ-2026-001
  final String name;
  final String description;
  final String client;
  final String? clientId;
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
    this.clientId,
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
    String? clientId,
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
      clientId: clientId ?? this.clientId,
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

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    Map<String, double> parseCategoryBudgets(dynamic raw) {
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), (v as num?)?.toDouble() ?? 0.0));
      }
      return const {};
    }

    List<String> parseTeamMemberIds(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return const [];
    }

    List<RevenueEntry> parseRevenues(dynamic raw) {
      if (raw is List) {
        return raw
            .whereType<Map<String, dynamic>>()
            .map(RevenueEntry.fromJson)
            .toList();
      }
      return const [];
    }

    final pCode = (json['project_id'] ?? json['projectId'] ?? json['project_code'] ?? '').toString();
    final pName = (json['name'] ?? json['project_name'] ?? '').toString();
    final pClient = (json['client'] ?? json['client_name'] ?? '').toString();
    final clientTypeStr = (json['client_type'] ?? json['clientType'] ?? 'private').toString();
    final assignmentTypeStr = (json['assignment_type'] ?? json['assignmentType'] ?? 'direct_consultancy').toString();
    final taxStatusStr = (json['tax_status'] ?? json['taxStatus'] ?? 'included').toString();
    final statusStr = (json['status'] ?? 'ongoing').toString();

    return ProjectModel(
      id: (json['id'] ?? '').toString(),
      projectId: pCode,
      name: pName,
      description: (json['description'] ?? '').toString(),
      client: pClient,
      clientId: json['client_id']?.toString() ?? json['clientId']?.toString(),
      clientType: ClientType.fromString(clientTypeStr),
      assignmentType: AssignmentType.fromString(assignmentTypeStr),
      grossProjectValue: (json['gross_project_value'] ?? json['grossProjectValue'] as num?)?.toDouble() ?? 0.0,
      taxStatus: TaxStatus.fromString(taxStatusStr),
      taxRate: (json['tax_rate'] ?? json['taxRate'] as num?)?.toDouble() ?? 0.10,
      expectedNetRevenue: (json['expected_net_revenue'] ?? json['expectedNetRevenue'] as num?)?.toDouble() ?? 0.0,
      advanceReceived: (json['advance_received'] ?? json['advanceReceived'] as num?)?.toDouble() ?? 0.0,
      amountReceived: (json['amount_received'] ?? json['amountReceived'] as num?)?.toDouble() ?? 0.0,
      amountReceivable: (json['amount_receivable'] ?? json['amountReceivable'] as num?)?.toDouble() ?? 0.0,
      budget: (json['budget'] as num?)?.toDouble() ?? 0.0,
      categoryBudgets: parseCategoryBudgets(json['category_budgets'] ?? json['categoryBudgets']),
      estimatedRemainingCost: (json['estimated_remaining_cost'] ?? json['estimatedRemainingCost'] as num?)?.toDouble() ?? 0.0,
      officeBenefitRate: (json['office_benefit_rate'] ?? json['officeBenefitRate'] as num?)?.toDouble() ?? 0.30,
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      teamMemberIds: parseTeamMemberIds(json['team_member_ids'] ?? json['teamMemberIds']),
      status: ProjectStatus.fromString(statusStr),
      revenueEntries: parseRevenues(json['revenue_entries'] ?? json['revenueEntries']),
      isClosed: json['is_closed'] ?? json['isClosed'] ?? false,
      closingSummary: json['closing_summary'] != null
          ? ProjectFinancialSummary.fromJson(json['closing_summary'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'project_code': projectId,
      'name': name,
      'description': description,
      'client': client,
      'client_name': client,
      if (clientId != null) 'client_id': clientId,
      'client_type': clientType.name,
      'assignment_type': assignmentType.name,
      'gross_project_value': grossProjectValue,
      'tax_status': taxStatus.name,
      'tax_rate': taxRate,
      'expected_net_revenue': expectedNetRevenue,
      'advance_received': advanceReceived,
      'amount_received': amountReceived,
      'amount_receivable': amountReceivable,
      'budget': budget,
      'category_budgets': categoryBudgets,
      'estimated_remaining_cost': estimatedRemainingCost,
      'office_benefit_rate': officeBenefitRate,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'team_member_ids': teamMemberIds,
      'status': status.name,
      'revenue_entries': revenueEntries.map((e) => e.toJson()).toList(),
      'is_closed': isClosed,
      if (closingSummary != null) 'closing_summary': closingSummary!.toJson(),
    };
  }
}
