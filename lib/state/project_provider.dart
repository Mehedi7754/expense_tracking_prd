import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/client_model.dart';
import '../models/project_model.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';

class ProjectNotifier extends Notifier<List<ProjectModel>> {
  static final List<ProjectModel> _initialProjects = [
    ProjectModel(
      id: 'proj_01',
      projectId: 'PRJ-2026-001',
      name: 'Enterprise Cloud ERP Platform',
      description: 'Modern microservices-based ERP migration with multi-tenant billing, inventory, and HR automation.',
      client: 'Apex Technologies Inc.',
      clientType: ClientType.private,
      assignmentType: AssignmentType.directConsultancy,
      grossProjectValue: 2500000.0, // ৳25 Lakhs
      taxStatus: TaxStatus.included,
      taxRate: 0.10,
      expectedNetRevenue: 2250000.0,
      advanceReceived: 500000.0,
      amountReceived: 1500000.0,
      amountReceivable: 1000000.0,
      budget: 2080000.0,
      categoryBudgets: {
        'equipment': 300000.0,
        'transportation': 450000.0,
        'food': 250000.0,
        'accommodation': 400000.0,
        'officecost': 200000.0,
        'officebenefit': 480000.0,
      },
      estimatedRemainingCost: 580000.0, // PRD Section 30 example
      officeBenefitRate: 0.30,
      startDate: DateTime(2026, 1, 15),
      endDate: DateTime(2026, 11, 30),
      teamMemberIds: ['usr_emp_01', 'usr_mgr_01', 'usr_fin_01', 'usr_adm_01'], // Fahim assigned
      status: ProjectStatus.ongoing,
      revenueEntries: [
        RevenueEntry(
          id: 'rev_01',
          projectId: 'proj_01',
          amount: 500000.0,
          date: DateTime(2026, 2, 1),
          note: 'Advance Mobilization Payment',
          createdBy: 'David Chen',
        ),
        RevenueEntry(
          id: 'rev_02',
          projectId: 'proj_01',
          amount: 1000000.0,
          date: DateTime(2026, 6, 15),
          note: 'Sprint Milestone 4 Delivery Signoff',
          createdBy: 'David Chen',
        ),
      ],
    ),
    ProjectModel(
      id: 'proj_02',
      projectId: 'PRJ-2026-002',
      name: 'Fintech Mobile Banking App (iOS & Android)',
      description: 'Omnichannel mobile banking application with biometric auth, QR payments, and real-time ledger sync.',
      client: 'Prime Bank Digital',
      clientType: ClientType.private,
      assignmentType: AssignmentType.subConsultancy,
      grossProjectValue: 1800000.0, // ৳18 Lakhs
      taxStatus: TaxStatus.excluded,
      taxRate: 0.15,
      expectedNetRevenue: 1800000.0,
      advanceReceived: 350000.0,
      amountReceived: 1000000.0,
      amountReceivable: 800000.0,
      budget: 1500000.0,
      categoryBudgets: {
        'equipment': 250000.0,
        'transportation': 350000.0,
        'food': 200000.0,
        'accommodation': 300000.0,
        'officecost': 150000.0,
        'officebenefit': 250000.0,
      },
      estimatedRemainingCost: 400000.0,
      officeBenefitRate: 0.20,
      startDate: DateTime(2026, 2, 1),
      endDate: DateTime(2026, 12, 15),
      teamMemberIds: ['usr_mgr_01', 'usr_view_01'], // Sarah & Rahim assigned
      status: ProjectStatus.ongoing,
      revenueEntries: [
        RevenueEntry(
          id: 'rev_03',
          projectId: 'proj_02',
          amount: 1000000.0,
          date: DateTime(2026, 4, 10),
          note: 'Beta Testing & Payment Gateway Integration',
          createdBy: 'David Chen',
        ),
      ],
    ),
    ProjectModel(
      id: 'proj_03',
      projectId: 'PRJ-2026-003',
      name: 'AI-Powered Telehealth Diagnostic Portal',
      description: 'HIPAA-compliant video telemedicine portal with AI-assisted clinical note summarization.',
      client: 'BioHealth AI Corp',
      clientType: ClientType.private,
      assignmentType: AssignmentType.directConsultancy,
      grossProjectValue: 1200000.0, // ৳12 Lakhs
      taxStatus: TaxStatus.included,
      taxRate: 0.10,
      expectedNetRevenue: 1080000.0,
      advanceReceived: 300000.0,
      amountReceived: 600000.0,
      amountReceivable: 600000.0,
      budget: 1050000.0,
      categoryBudgets: {
        'equipment': 150000.0,
        'transportation': 250000.0,
        'food': 150000.0,
        'accommodation': 200000.0,
        'officecost': 100000.0,
        'officebenefit': 200000.0,
      },
      estimatedRemainingCost: 200000.0,
      officeBenefitRate: 0.30,
      startDate: DateTime(2026, 3, 1),
      endDate: DateTime(2026, 9, 30),
      teamMemberIds: ['usr_mgr_01', 'usr_adm_01'],
      status: ProjectStatus.ongoing,
      revenueEntries: [
        RevenueEntry(
          id: 'rev_04',
          projectId: 'proj_03',
          amount: 600000.0,
          date: DateTime(2026, 5, 20),
          note: 'AI Model Validation & Clinician UAT Signoff',
          createdBy: 'David Chen',
        ),
      ],
    ),
    ProjectModel(
      id: 'proj_04',
      projectId: 'PRJ-2026-004',
      name: 'Cybersecurity SOC & DevSecOps Pipeline',
      description: 'Automated CI/CD security scanning, Kubernetes posture management, and 24/7 SOC incident response.',
      client: 'GovTech Defense Systems',
      clientType: ClientType.government,
      assignmentType: AssignmentType.government,
      grossProjectValue: 3500000.0, // ৳35 Lakhs
      taxStatus: TaxStatus.notApplicable,
      taxRate: 0.0,
      expectedNetRevenue: 3500000.0,
      advanceReceived: 800000.0,
      amountReceived: 1800000.0,
      amountReceivable: 1700000.0,
      budget: 2800000.0,
      categoryBudgets: {
        'equipment': 600000.0,
        'transportation': 700000.0,
        'food': 350000.0,
        'accommodation': 500000.0,
        'officecost': 300000.0,
        'officebenefit': 735000.0,
      },
      estimatedRemainingCost: 950000.0,
      officeBenefitRate: 0.30,
      startDate: DateTime(2026, 1, 10),
      endDate: DateTime(2026, 12, 31),
      teamMemberIds: ['usr_adm_01', 'usr_fin_01'],
      status: ProjectStatus.ongoing,
      revenueEntries: [
        RevenueEntry(
          id: 'rev_05',
          projectId: 'proj_04',
          amount: 1800000.0,
          date: DateTime(2026, 4, 15),
          note: 'DevSecOps Pipeline Hardening & Penetration Testing Report',
          createdBy: 'David Chen',
        ),
      ],
    ),
    ProjectModel(
      id: 'proj_05',
      projectId: 'PRJ-2025-012',
      name: 'Supply Chain SaaS Integration 2025',
      description: 'High-throughput Kafka event streaming for multi-vendor warehouse logistics.',
      client: 'Apex Logistics Cloud',
      clientType: ClientType.private,
      assignmentType: AssignmentType.private,
      grossProjectValue: 850000.0, // ৳8.5 Lakhs
      taxStatus: TaxStatus.included,
      taxRate: 0.10,
      expectedNetRevenue: 765000.0,
      advanceReceived: 250000.0,
      amountReceived: 850000.0,
      amountReceivable: 0.0,
      budget: 650000.0,
      categoryBudgets: {
        'equipment': 120000.0,
        'transportation': 150000.0,
        'food': 80000.0,
        'accommodation': 100000.0,
        'officecost': 50000.0,
        'officebenefit': 150000.0,
      },
      estimatedRemainingCost: 0.0,
      officeBenefitRate: 0.25,
      startDate: DateTime(2025, 7, 1),
      endDate: DateTime(2025, 12, 15),
      teamMemberIds: ['usr_mgr_01', 'usr_adm_01'],
      status: ProjectStatus.completed,
      isClosed: true,
      closingSummary: ProjectFinancialSummary(
        contractValue: 850000.0,
        taxInfo: 'IT-VAT: Included (10%)',
        totalRevenue: 850000.0,
        directExpenditure: 440000.0,
        officeBenefit: 110000.0,
        netProjectCost: 550000.0,
        profit: 300000.0,
        profitMargin: 35.3,
        totalReceivable: 0.0,
        receiptComplianceRate: 94.5,
        teamMembersCount: 4,
        budgetVariance: -15.4,
        closedAt: DateTime(2025, 12, 20),
      ),
      revenueEntries: [
        RevenueEntry(
          id: 'rev_06',
          projectId: 'proj_05',
          amount: 850000.0,
          date: DateTime(2025, 12, 18),
          note: 'Full Project Settlement',
          createdBy: 'David Chen',
        ),
      ],
    ),
  ];

  @override
  List<ProjectModel> build() => _initialProjects;

  /// The most important rule: PRD Section 1
  /// A member should never automatically see the entire company project portfolio.
  List<ProjectModel> getProjectsForUser(UserModel? user) {
    if (user == null) return [];
    if (user.role == UserRole.mainAdmin || user.role == UserRole.finance) {
      return state;
    }
    // Project Member, Viewer, or Project Manager sees only assigned projects
    return state.where((p) => p.teamMemberIds.contains(user.id)).toList();
  }

  void addProject({
    required String name,
    required String description,
    required String client,
    ClientType clientType = ClientType.private,
    AssignmentType assignmentType = AssignmentType.directConsultancy,
    required double grossProjectValue,
    TaxStatus taxStatus = TaxStatus.included,
    double taxRate = 0.10,
    double advanceReceived = 0.0,
    double amountReceived = 0.0,
    required double budget,
    Map<String, double> categoryBudgets = const {},
    double estimatedRemainingCost = 0.0,
    double officeBenefitRate = 0.30,
    required DateTime startDate,
    required DateTime endDate,
    required List<String> teamMemberIds,
  }) {
    final nextNumber = state.length + 1;
    final generatedId = 'PRJ-2026-${nextNumber.toString().padLeft(3, '0')}';
    final netRevenue = taxStatus == TaxStatus.included
        ? grossProjectValue * (1 - taxRate)
        : grossProjectValue;
    final receivable = grossProjectValue - amountReceived;

    final newProj = ProjectModel(
      id: 'proj_${DateTime.now().microsecondsSinceEpoch}',
      projectId: generatedId,
      name: name,
      description: description,
      client: client,
      clientType: clientType,
      assignmentType: assignmentType,
      grossProjectValue: grossProjectValue,
      taxStatus: taxStatus,
      taxRate: taxRate,
      expectedNetRevenue: netRevenue,
      advanceReceived: advanceReceived,
      amountReceived: amountReceived,
      amountReceivable: receivable > 0 ? receivable : 0.0,
      budget: budget,
      categoryBudgets: categoryBudgets,
      estimatedRemainingCost: estimatedRemainingCost,
      officeBenefitRate: officeBenefitRate,
      startDate: startDate,
      endDate: endDate,
      teamMemberIds: teamMemberIds,
      status: ProjectStatus.ongoing,
    );
    state = [...state, newProj];
  }

  void updateProject(ProjectModel updated) {
    state = [
      for (final p in state)
        if (p.id == updated.id) updated else p,
    ];
  }

  void updateEstimatedRemainingCost(String projectId, double newRemaining) {
    state = [
      for (final p in state)
        if (p.id == projectId)
          p.copyWith(estimatedRemainingCost: newRemaining)
        else
          p,
    ];
  }

  void addRevenue({
    required String projectId,
    required double amount,
    required DateTime date,
    required String note,
    required String createdBy,
  }) {
    final entry = RevenueEntry(
      id: 'rev_${DateTime.now().microsecondsSinceEpoch}',
      projectId: projectId,
      amount: amount,
      date: date,
      note: note,
      createdBy: createdBy,
    );

    state = [
      for (final p in state)
        if (p.id == projectId)
          p.copyWith(
            revenueEntries: [...p.revenueEntries, entry],
            amountReceived: p.amountReceived + amount,
            amountReceivable: (p.grossProjectValue - (p.amountReceived + amount)).clamp(0.0, double.infinity),
          )
        else
          p,
    ];
  }

  void closeProject({
    required String projectId,
    required ProjectFinancialSummary summary,
  }) {
    state = [
      for (final p in state)
        if (p.id == projectId)
          p.copyWith(
            status: ProjectStatus.completed,
            isClosed: true,
            closingSummary: summary,
          )
        else
          p,
    ];
  }
}

final projectProvider =
    NotifierProvider<ProjectNotifier, List<ProjectModel>>(ProjectNotifier.new);
