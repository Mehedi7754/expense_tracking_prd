import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/client_model.dart';
import '../models/project_model.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import '../repositories/project_repository.dart';

const String _kCustomProjectsKey = 'gw_custom_projects_cache';

bool _isTestEnvironment() {
  if (kIsWeb) return false;
  return Platform.environment.containsKey('FLUTTER_TEST');
}

class ProjectNotifier extends Notifier<List<ProjectModel>> {
  @override
  List<ProjectModel> build() {
    _loadCachedProjects();
    return const [];
  }

  Future<void> _loadCachedProjects() async {
    if (_isTestEnvironment()) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_kCustomProjectsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        final customProjects = decoded
            .whereType<Map<String, dynamic>>()
            .map(ProjectModel.fromJson)
            .toList();

        state = customProjects;
        debugPrint('[ProjectNotifier] Restored ${customProjects.length} projects from local storage');
      } else {
        state = const [];
      }
    } catch (e) {
      debugPrint('[ProjectNotifier] Error loading cached projects: $e');
      state = const [];
    }
  }

  Future<void> _persistProjects() async {
    if (_isTestEnvironment()) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = state.map((p) => p.toJson()).toList();
      await prefs.setString(_kCustomProjectsKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[ProjectNotifier] Error persisting projects: $e');
    }
  }

  /// The most important rule: PRD Section 1
  /// A member should never automatically see the entire company project portfolio.
  List<ProjectModel> getProjectsForUser(UserModel? user) {
    if (user == null) return [];
    if (user.role == UserRole.mainAdmin || user.role == UserRole.finance) {
      return state;
    }
    // Project Member, Viewer, or Project Manager sees assigned projects or projects they created
    return state.where((p) {
      return p.hasMember(user.id) ||
          p.createdById == user.id ||
          user.assignedProjectIds.contains(p.id) ||
          user.assignedProjectIds.contains(p.projectId);
    }).toList();
  }

  Future<void> fetchProjects() async {
    try {
      final repo = ref.read(projectRepositoryProvider);
      final remoteProjects = await repo.getProjects();
      final remoteIds = remoteProjects.map((p) => p.id).toSet();
      final remoteCodes = remoteProjects.map((p) => p.projectId).toSet();

      // Preserve locally created projects that have not yet reached the backend
      final localOnly = state
          .where((p) => !remoteIds.contains(p.id) && !remoteCodes.contains(p.projectId))
          .toList();

      state = [...remoteProjects, ...localOnly];
      await _persistProjects();
      debugPrint('[ProjectNotifier] Synchronized ${remoteProjects.length} projects from backend');
    } catch (e) {
      debugPrint('[ProjectNotifier] Backend fetch failed, using offline projects: $e');
    }
  }

  void setProjects(List<ProjectModel> projects) {
    state = projects;
    _persistProjects();
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
    String? createdById,
    String? imageUrl,
  }) async {
    final uniqueMicro = DateTime.now().microsecondsSinceEpoch % 1000000;
    final generatedId = 'PRJ-${DateTime.now().year}-${uniqueMicro.toString().padLeft(6, '0')}';
    final netRevenue = taxStatus == TaxStatus.included
        ? grossProjectValue * (1 - taxRate)
        : grossProjectValue;
    final receivable = grossProjectValue - amountReceived;

    final effectiveTeamMembers = <String>{
      ...teamMemberIds,
      if (createdById != null && createdById.isNotEmpty) createdById,
    }.toList();

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
      teamMemberIds: effectiveTeamMembers,
      createdById: createdById,
      status: ProjectStatus.ongoing,
      imageUrl: imageUrl,
    );

    // Optimistic local update & instant persistence so it's NEVER lost on restart
    state = [newProj, ...state];
    await _persistProjects();

    try {
      final repo = ref.read(projectRepositoryProvider);
      final saved = await repo.createProject(newProj);
      state = [
        for (final p in state)
          if (p.id == newProj.id || p.projectId == newProj.projectId) saved else p,
      ];
      await _persistProjects();
      debugPrint('[ProjectNotifier] Successfully created project on backend: ${saved.projectId}');
      return saved;
    } catch (e) {
      debugPrint('[ProjectNotifier] Error saving project to backend: $e. Retained in local storage.');
      // Local state preserved for offline resiliency
      return newProj;
    }
  }

  Future<void> updateProject(ProjectModel updated) async {
    state = [
      for (final p in state)
        if (p.id == updated.id) updated else p,
    ];
    await _persistProjects();

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
    _persistProjects();
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
    await _persistProjects();

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
    await _persistProjects();

    try {
      final repo = ref.read(projectRepositoryProvider);
      await repo.closeProject(projectId, summary);
    } catch (_) {
      // Offline fallback
    }
  }

  /// Updates the project progress (0% - 100%) and records the audit user and timestamp.
  /// Accessible to Admin and Manager roles.
  void updateProjectProgress({
    required String projectId,
    required double progressPercentage,
    required String updatedById,
    required String updatedByName,
  }) {
    final clamped = progressPercentage.clamp(0.0, 100.0);
    final now = DateTime.now();
    state = [
      for (final p in state)
        if (p.id == projectId)
          p.copyWith(
            progressPercentage: clamped,
            progressUpdatedAt: now,
            progressUpdatedById: updatedById,
            progressUpdatedByName: updatedByName,
          )
        else
          p,
    ];
    _persistProjects();
  }
}

final projectProvider =
    NotifierProvider<ProjectNotifier, List<ProjectModel>>(ProjectNotifier.new);
