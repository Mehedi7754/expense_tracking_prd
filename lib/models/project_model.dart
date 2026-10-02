import 'client_model.dart';

double _asDouble(dynamic val, [double fallback = 0.0]) {
  if (val == null) return fallback;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val) ?? fallback;
  return fallback;
}

int _asInt(dynamic val, [int fallback = 0]) {
  if (val == null) return fallback;
  if (val is num) return val.toInt();
  if (val is String) return int.tryParse(val) ?? fallback;
  return fallback;
}

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
      amount: _asDouble(json['amount']),
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

  String get toApiValue {
    switch (this) {
      case ProjectStatus.proposal:
        return 'proposal';
      case ProjectStatus.approved:
        return 'approved';
      case ProjectStatus.ongoing:
        return 'ongoing';
      case ProjectStatus.completed:
        return 'completed';
      case ProjectStatus.suspended:
        return 'suspended';
      case ProjectStatus.cancelled:
        return 'cancelled';
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

enum ProjectProgressStage {
  notStarted,
  inProgress,
  nearCompletion,
  completed;

  String get displayName {
    switch (this) {
      case ProjectProgressStage.notStarted:
        return 'Not Started';
      case ProjectProgressStage.inProgress:
        return 'In Progress';
      case ProjectProgressStage.nearCompletion:
        return 'Near Completion';
      case ProjectProgressStage.completed:
        return 'Completed';
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

  String get toApiValue {
    switch (this) {
      case AssignmentType.directConsultancy:
        return 'direct_consultancy';
      case AssignmentType.subConsultancy:
        return 'sub_consultancy';
      case AssignmentType.government:
        return 'government';
      case AssignmentType.private:
        return 'private';
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

  String get toApiValue {
    switch (this) {
      case TaxStatus.included:
        return 'included';
      case TaxStatus.excluded:
        return 'excluded';
      case TaxStatus.notApplicable:
        return 'not_applicable';
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
      contractValue: _asDouble(json['contract_value'] ?? json['contractValue']),
      taxInfo: (json['tax_info'] ?? json['taxInfo'] ?? '').toString(),
      totalRevenue: _asDouble(json['total_revenue'] ?? json['totalRevenue']),
      directExpenditure: _asDouble(json['direct_expenditure'] ?? json['directExpenditure']),
      officeBenefit: _asDouble(json['office_benefit'] ?? json['officeBenefit']),
      netProjectCost: _asDouble(json['net_project_cost'] ?? json['netProjectCost']),
      profit: _asDouble(json['profit']),
      profitMargin: _asDouble(json['profit_margin'] ?? json['profitMargin']),
      totalReceivable: _asDouble(json['total_receivable'] ?? json['totalReceivable']),
      receiptComplianceRate: _asDouble(json['receipt_compliance_rate'] ?? json['receiptComplianceRate']),
      teamMembersCount: _asInt(json['team_members_count'] ?? json['teamMembersCount']),
      budgetVariance: _asDouble(json['budget_variance'] ?? json['budgetVariance']),
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

  // Project Progress Tracking (PRD Section & Admin/Manager controls)
  final double progressPercentage; // 0.0 to 100.0
  final DateTime? progressUpdatedAt;
  final String? progressUpdatedByName;
  final String? progressUpdatedById;
  final String? createdById;
  final String? imageUrl; // Project Cover Image / Banner

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
    this.progressPercentage = 0.0,
    this.progressUpdatedAt,
    this.progressUpdatedByName,
    this.progressUpdatedById,
    this.createdById,
    this.imageUrl,
  });

  // Visual status indicators based on progress:
  // Not Started (0%), In Progress (1%-74%), Near Completion (75%-99%), Completed (100%)
  ProjectProgressStage get progressStage {
    if (progressPercentage <= 0.0) return ProjectProgressStage.notStarted;
    if (progressPercentage < 75.0) return ProjectProgressStage.inProgress;
    if (progressPercentage < 100.0) return ProjectProgressStage.nearCompletion;
    return ProjectProgressStage.completed;
  }

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
    double? progressPercentage,
    DateTime? progressUpdatedAt,
    String? progressUpdatedByName,
    String? progressUpdatedById,
    String? createdById,
    String? imageUrl,
    bool clearImageUrl = false,
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
      progressPercentage: progressPercentage ?? this.progressPercentage,
      progressUpdatedAt: progressUpdatedAt ?? this.progressUpdatedAt,
      progressUpdatedByName: progressUpdatedByName ?? this.progressUpdatedByName,
      progressUpdatedById: progressUpdatedById ?? this.progressUpdatedById,
      createdById: createdById ?? this.createdById,
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
    );
  }

  static const Map<String, String> demoToUuid = {
    'usr_adm_01': 'a0000000-0000-0000-0000-000000000001',
    'usr_mgr_01': 'a0000000-0000-0000-0000-000000000002',
    'usr_emp_01': 'a0000000-0000-0000-0000-000000000003',
    'usr_fin_01': 'a0000000-0000-0000-0000-000000000004',
    'usr_view_01': 'a0000000-0000-0000-0000-000000000005',
  };

  static const Map<String, String> uuidToDemo = {
    'a0000000-0000-0000-0000-000000000001': 'usr_adm_01',
    'a0000000-0000-0000-0000-000000000002': 'usr_mgr_01',
    'a0000000-0000-0000-0000-000000000003': 'usr_emp_01',
    'a0000000-0000-0000-0000-000000000004': 'usr_fin_01',
    'a0000000-0000-0000-0000-000000000005': 'usr_view_01',
  };

  bool hasMember(String userId) {
    if (createdById != null &&
        (createdById == userId ||
            demoToUuid[userId] == createdById ||
            uuidToDemo[userId] == createdById)) {
      return true;
    }
    if (teamMemberIds.contains(userId)) return true;
    final mapped = demoToUuid[userId] ?? uuidToDemo[userId];
    if (mapped != null && teamMemberIds.contains(mapped)) return true;
    return false;
  }

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    List<String> parseTeamMemberIds(dynamic raw) {
      if (raw is List) {
        final result = <String>{};
        for (final item in raw) {
          final s = item.toString();
          result.add(s);
          if (uuidToDemo.containsKey(s)) {
            result.add(uuidToDemo[s]!);
          } else if (demoToUuid.containsKey(s)) {
            result.add(demoToUuid[s]!);
          }
        }
        return result.toList();
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

    final rawCatBudgets = json['category_budgets'] ?? json['categoryBudgets'];
    final rawCatMap = rawCatBudgets is Map ? rawCatBudgets : const {};
    
    final metaProgress = _asDouble(rawCatMap['_meta_progress']);
    final metaProgressUpdatedAt = rawCatMap['_meta_progress_updated_at'] != null
        ? DateTime.tryParse(rawCatMap['_meta_progress_updated_at'].toString())
        : null;
    final metaMembers = parseTeamMemberIds(rawCatMap['_meta_team_members']);
    final directMembers = parseTeamMemberIds(json['team_member_ids'] ?? json['teamMemberIds']);
    final mergedMembers = {...directMembers, ...metaMembers}.toList();

    final categoryBudgetsMap = <String, double>{};
    if (rawCatBudgets is Map) {
      for (final entry in rawCatBudgets.entries) {
        final k = entry.key.toString();
        if (k.startsWith('_meta_')) continue;
        if (entry.value != null) {
          categoryBudgetsMap[k] = _asDouble(entry.value);
        }
      }
    }

    return ProjectModel(
      id: (json['id'] ?? '').toString(),
      projectId: pCode,
      name: pName,
      description: (json['description'] ?? '').toString(),
      client: pClient,
      clientId: json['client_id']?.toString() ?? json['clientId']?.toString(),
      clientType: ClientType.fromString(clientTypeStr),
      assignmentType: AssignmentType.fromString(assignmentTypeStr),
      grossProjectValue: _asDouble(json['gross_project_value'] ?? json['grossProjectValue']),
      taxStatus: TaxStatus.fromString(taxStatusStr),
      taxRate: _asDouble(json['tax_rate'] ?? json['taxRate'], 0.10),
      expectedNetRevenue: _asDouble(json['expected_net_revenue'] ?? json['expectedNetRevenue']),
      advanceReceived: _asDouble(json['advance_received'] ?? json['advanceReceived']),
      amountReceived: _asDouble(json['amount_received'] ?? json['amountReceived']),
      amountReceivable: _asDouble(json['amount_receivable'] ?? json['amountReceivable']),
      budget: _asDouble(json['budget']),
      categoryBudgets: categoryBudgetsMap,
      estimatedRemainingCost: _asDouble(json['estimated_remaining_cost'] ?? json['estimatedRemainingCost']),
      officeBenefitRate: _asDouble(json['office_benefit_rate'] ?? json['officeBenefitRate'], 0.30),
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      teamMemberIds: mergedMembers,
      status: ProjectStatus.fromString(statusStr),
      revenueEntries: parseRevenues(json['revenue_entries'] ?? json['revenueEntries']),
      isClosed: json['is_closed'] ?? json['isClosed'] ?? false,
      closingSummary: json['closing_summary'] != null
          ? ProjectFinancialSummary.fromJson(json['closing_summary'] as Map<String, dynamic>)
          : null,
      progressPercentage: _asDouble(json['progress_percentage'] ?? json['progressPercentage'] ?? metaProgress),
      progressUpdatedAt: json['progress_updated_at'] != null
          ? DateTime.tryParse(json['progress_updated_at'].toString())
          : metaProgressUpdatedAt,
      progressUpdatedByName: json['progress_updated_by_name']?.toString(),
      progressUpdatedById: json['progress_updated_by_id']?.toString(),
      createdById: json['created_by_id']?.toString() ?? json['createdById']?.toString() ?? json['created_by']?.toString(),
      imageUrl: (json['image_url'] ?? json['imageUrl'])?.toString(),
    );
  }

  Map<String, dynamic> toJson({bool forApi = false, bool isNewCreation = false}) {
    final validTeamMembers = teamMemberIds
        .map((id) => demoToUuid[id] ?? id)
        .where((id) => id.trim().isNotEmpty)
        .toList();

    final isTemporaryId = id.startsWith('proj_');
    final isCollidingCode = RegExp(r'^PRJ-\d{4}-00[1-5]$').hasMatch(projectId);

    return {
      if (!forApi)
        'id': id
      else if (!isTemporaryId && !isNewCreation && RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false).hasMatch(id))
        'id': id,
      if (!forApi) ...{
        'project_id': projectId,
        'project_code': projectId,
      } else if (!isTemporaryId && !isCollidingCode && !isNewCreation) ...{
        'project_id': projectId,
        'project_code': projectId,
      },
      'name': name,
      'description': description,
      'client': client,
      'client_name': client,
      if (clientId != null && clientId!.isNotEmpty && RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false).hasMatch(clientId!)) 'client_id': clientId,
      'client_type': clientType.name,
      'assignment_type': assignmentType.toApiValue,
      'gross_project_value': grossProjectValue,
      'tax_status': taxStatus.toApiValue,
      'tax_rate': taxRate,
      'expected_net_revenue': expectedNetRevenue,
      'advance_received': advanceReceived,
      'amount_received': amountReceived,
      'amount_receivable': amountReceivable,
      'budget': budget,
      'category_budgets': {
        ...categoryBudgets,
        if (progressPercentage > 0) '_meta_progress': progressPercentage,
        if (progressUpdatedAt != null) '_meta_progress_updated_at': progressUpdatedAt!.toIso8601String(),
        if (validTeamMembers.isNotEmpty) '_meta_team_members': validTeamMembers,
      },
      'estimated_remaining_cost': estimatedRemainingCost,
      'office_benefit_rate': officeBenefitRate,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'team_member_ids': validTeamMembers,
      'teamMemberIds': validTeamMembers,
      'status': status.toApiValue,
      'revenue_entries': revenueEntries.map((e) => e.toJson()).toList(),
      'is_closed': isClosed,
      if (closingSummary != null) 'closing_summary': closingSummary!.toJson(),
      'progress_percentage': progressPercentage,
      'progressPercentage': progressPercentage,
      if (progressUpdatedAt != null) 'progress_updated_at': progressUpdatedAt!.toIso8601String(),
      if (progressUpdatedByName != null) 'progress_updated_by_name': progressUpdatedByName,
      if (progressUpdatedById != null) 'progress_updated_by_id': progressUpdatedById,
      if (createdById != null && createdById!.isNotEmpty) 'created_by': demoToUuid[createdById] ?? createdById,
      if (createdById != null && createdById!.isNotEmpty) 'created_by_id': demoToUuid[createdById] ?? createdById,
      if (!forApi && imageUrl != null && imageUrl!.isNotEmpty) 'image_url': imageUrl,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
