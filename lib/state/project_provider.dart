import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/client_model.dart';
import '../models/project_model.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import '../repositories/project_repository.dart';

class ProjectNotifier extends Notifier<List<ProjectModel>> {
  @override
  List<ProjectModel> build() {
    // Default clean empty state on startup (no hardcoded demo projects)
    return const [];
  }

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

  Future<void> fetchProjects() async {
    try {
      final repo = ref.read(projectRepositoryProvider);
      final projects = await repo.getProjects();
      state = projects;
    } catch (_) {
      // Keep existing state on network disconnect
    }
  }

  void setProjects(List<ProjectModel> projects) {
    state = projects;
  }

  Future<ProjectModel> addProject({
    required String name,
    required String description,
    required String client,
    String? clientId,
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
  }) async {
    final nextNumber = state.length + 1;
    final generatedId = 'PRJ-${DateTime.now().year}-${nextNumber.toString().padLeft(3, '0')}';
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
      clientId: clientId,
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

    // Optimistic local update
    state = [...state, newProj];

    try {
      final repo = ref.read(projectRepositoryProvider);
      final saved = await repo.createProject(newProj);
      state = [
        for (final p in state)
          if (p.id == newProj.id) saved else p,
      ];
      return saved;
    } catch (_) {
      // Local state preserved for offline resiliency
      return newProj;
    }
  }

  Future<void> updateProject(ProjectModel updated) async {
    state = [
      for (final p in state)
        if (p.id == updated.id) updated else p,
    ];

    try {
      final repo = ref.read(projectRepositoryProvider);
      await repo.updateProject(updated);
    } catch (_) {
      // Offline fallback
    }
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

  Future<void> addRevenue({
    required String projectId,
    required double amount,
    required DateTime date,
    required String note,
    required String createdBy,
  }) async {
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

    try {
      final repo = ref.read(projectRepositoryProvider);
      await repo.addRevenue(projectId, entry);
    } catch (_) {
      // Offline fallback
    }
  }

  Future<void> closeProject({
    required String projectId,
    required ProjectFinancialSummary summary,
  }) async {
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

    try {
      final repo = ref.read(projectRepositoryProvider);
      await repo.closeProject(projectId, summary);
    } catch (_) {
      // Offline fallback
    }
  }
}

final projectProvider =
    NotifierProvider<ProjectNotifier, List<ProjectModel>>(ProjectNotifier.new);
