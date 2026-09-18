import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project_model.dart';

class ProjectNotifier extends Notifier<List<ProjectModel>> {
  static final List<ProjectModel> _initialProjects = [
    ProjectModel(
      id: 'proj_01',
      name: 'Mobile App Modernization',
      description: 'Full redesign and Flutter mobile migration for core enterprise platform.',
      client: 'Acme Corporation',
      budget: 45000.0,
      expectedRevenue: 65000.0,
      startDate: DateTime(2026, 1, 15),
      endDate: DateTime(2026, 11, 30),
      teamMemberIds: ['usr_emp_01', 'usr_mgr_01', 'usr_fin_01', 'usr_adm_01'],
      status: ProjectStatus.active,
      revenueEntries: [
        RevenueEntry(
          id: 'rev_01',
          projectId: 'proj_01',
          amount: 30000.0,
          date: DateTime(2026, 3, 1),
          note: 'Milestone 1 Deliverable Signoff',
          createdBy: 'David Chen',
        ),
        RevenueEntry(
          id: 'rev_02',
          projectId: 'proj_01',
          amount: 25000.0,
          date: DateTime(2026, 6, 15),
          note: 'Milestone 2 Alpha Release',
          createdBy: 'David Chen',
        ),
      ],
    ),
    ProjectModel(
      id: 'proj_02',
      name: 'Cloud Infrastructure Migration',
      description: 'AWS multi-region containerized architecture transition.',
      client: 'Horizon Global Logistics',
      budget: 80000.0,
      expectedRevenue: 115000.0,
      startDate: DateTime(2026, 2, 1),
      endDate: DateTime(2026, 12, 15),
      teamMemberIds: ['usr_emp_01', 'usr_mgr_01', 'usr_emp_02'],
      status: ProjectStatus.active,
      revenueEntries: [
        RevenueEntry(
          id: 'rev_03',
          projectId: 'proj_02',
          amount: 50000.0,
          date: DateTime(2026, 4, 10),
          note: 'Initial Cloud Architecture Setup',
          createdBy: 'David Chen',
        ),
      ],
    ),
    ProjectModel(
      id: 'proj_03',
      name: 'AI Analytics Pipeline',
      description: 'Real-time telemetry and predictive reporting infrastructure.',
      client: 'FinCorp Solutions',
      budget: 25000.0,
      expectedRevenue: 30000.0,
      startDate: DateTime(2026, 3, 1),
      endDate: DateTime(2026, 8, 30),
      teamMemberIds: ['usr_emp_01', 'usr_mgr_01'],
      status: ProjectStatus.active,
      revenueEntries: [
        RevenueEntry(
          id: 'rev_04',
          projectId: 'proj_03',
          amount: 15000.0,
          date: DateTime(2026, 5, 20),
          note: 'Phase 1 Model Ingestion',
          createdBy: 'David Chen',
        ),
      ],
    ),
    ProjectModel(
      id: 'proj_04',
      name: 'Internal Security Compliance',
      description: 'SOC2 Type II compliance audit and penetration testing.',
      client: 'Internal Corporate',
      budget: 18000.0,
      expectedRevenue: 0.0,
      startDate: DateTime(2026, 1, 10),
      endDate: DateTime(2026, 10, 31),
      teamMemberIds: ['usr_mgr_01', 'usr_adm_01'],
      status: ProjectStatus.active,
      revenueEntries: [],
    ),
  ];

  @override
  List<ProjectModel> build() => _initialProjects;

  void addProject({
    required String name,
    required String description,
    required String client,
    required double budget,
    required double expectedRevenue,
    required DateTime startDate,
    required DateTime endDate,
    required List<String> teamMemberIds,
  }) {
    final newProj = ProjectModel(
      id: 'proj_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      description: description,
      client: client,
      budget: budget,
      expectedRevenue: expectedRevenue,
      startDate: startDate,
      endDate: endDate,
      teamMemberIds: teamMemberIds,
      status: ProjectStatus.active,
    );
    state = [...state, newProj];
  }

  void updateProject(ProjectModel updated) {
    state = [
      for (final p in state)
        if (p.id == updated.id) updated else p,
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
          p.copyWith(revenueEntries: [...p.revenueEntries, entry])
        else
          p,
    ];
  }
}

final projectProvider = NotifierProvider<ProjectNotifier, List<ProjectModel>>(ProjectNotifier.new);
