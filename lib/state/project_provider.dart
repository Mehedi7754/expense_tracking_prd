import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/environment_utils.dart';
import '../core/utils/fetch_cache_mixin.dart';
import '../models/client_model.dart';
import '../models/notification_model.dart';
import '../models/project_model.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import '../repositories/project_repository.dart';
import 'notification_provider.dart';

const String _kCustomProjectsKey = 'gw_custom_projects_cache';
const String _kDeletedProjectIdsKey = 'gw_deleted_project_ids_cache';

class ProjectNotifier extends Notifier<List<ProjectModel>>
    with FetchCacheMixin {
  @override
  List<ProjectModel> build() {
    _loadCachedProjects();
    return const [];
  }

  Future<Set<String>> _getDeletedProjectIds() async {
    if (EnvironmentUtils.isTestEnvironment) return {};
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kDeletedProjectIdsKey) ?? [];
      return list.toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> _recordDeletedProjectIds(Iterable<String> ids) async {
    if (EnvironmentUtils.isTestEnvironment) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final current =
          (prefs.getStringList(_kDeletedProjectIdsKey) ?? []).toSet();
      current.addAll(ids.where((id) => id.isNotEmpty));
      await prefs.setStringList(_kDeletedProjectIdsKey, current.toList());
    } catch (_) {}
  }

  bool _isProjectDeleted(ProjectModel p, Set<String> deletedSet) {
    if (deletedSet.contains(p.id)) return true;
    if (deletedSet.contains(p.projectId)) return true;
    if (deletedSet.contains(p.id.toLowerCase())) return true;
    if (deletedSet.contains(p.projectId.toLowerCase())) return true;
    if (deletedSet.contains(p.name.trim().toLowerCase())) return true;
    return false;
  }

  Future<void> _loadCachedProjects() async {
    if (EnvironmentUtils.isTestEnvironment) return;
    try {
      final deletedIds = await _getDeletedProjectIds();
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_kCustomProjectsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        final customProjects =
            decoded
                .whereType<Map<String, dynamic>>()
                .map(ProjectModel.fromJson)
                .where((p) => !_isProjectDeleted(p, deletedIds))
                .toList();

        state = customProjects;
      } else {
        state = const [];
      }
    } catch (_) {
      state = const [];
    }
  }

  Future<void> _persistProjects() async {
    if (EnvironmentUtils.isTestEnvironment) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = state.map((p) => p.toJson()).toList();
      await prefs.setString(_kCustomProjectsKey, jsonEncode(jsonList));
    } catch (_) {}
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

  /// Fetches projects from backend with cache check.
  /// Set [force] to `true` for pull-to-refresh or post-mutation sync.
  Future<void> fetchProjects({bool force = false}) async {
    if (!shouldFetch(force: force, hasData: state.isNotEmpty)) return;

    markFetchStarted();
    try {
      final repo = ref.read(projectRepositoryProvider);
      final rawRemoteProjects = await repo.getProjects();

      // Fetch deletedIds AFTER API call to prevent race condition if deletion happens during fetch
      final deletedIds = await _getDeletedProjectIds();

      final remoteProjects =
          rawRemoteProjects
              .where((p) => !_isProjectDeleted(p, deletedIds))
              .toList();

      final remoteIds = remoteProjects.map((p) => p.id).toSet();
      final remoteCodes = remoteProjects.map((p) => p.projectId).toSet();

      final localMap = <String, ProjectModel>{for (final p in state) p.id: p};
      final mergedProjects = <ProjectModel>[];

      for (final remote in remoteProjects) {
        final local = localMap[remote.id];
        if (local != null) {
          // Merge team members: combine so no assigned member is dropped
          final combinedMembers =
              {...remote.teamMemberIds, ...local.teamMemberIds}.toList();

          double progress = remote.progressPercentage;
          DateTime? progressUpdatedAt = remote.progressUpdatedAt;
          String? progressUpdatedByName = remote.progressUpdatedByName;
          String? progressUpdatedById = remote.progressUpdatedById;

          if (local.progressUpdatedAt != null &&
              (remote.progressUpdatedAt == null ||
                  local.progressUpdatedAt!.isAfter(
                    remote.progressUpdatedAt!,
                  ))) {
            progress = local.progressPercentage;
            progressUpdatedAt = local.progressUpdatedAt;
            progressUpdatedByName = local.progressUpdatedByName;
            progressUpdatedById = local.progressUpdatedById;
          } else if (remote.progressPercentage > 0) {
            progress = remote.progressPercentage;
          } else if (local.progressPercentage > 0) {
            progress = local.progressPercentage;
          }

          final merged = remote.copyWith(
            teamMemberIds: combinedMembers,
            progressPercentage: progress,
            progressUpdatedAt: progressUpdatedAt,
            progressUpdatedByName: progressUpdatedByName,
            progressUpdatedById: progressUpdatedById,
          );
          mergedProjects.add(merged);
        } else {
          mergedProjects.add(remote);
        }
      }

      // Preserve locally created projects that have not yet reached the backend
      final localOnly =
          state
              .where(
                (p) =>
                    p.id.startsWith('proj_') &&
                    !_isProjectDeleted(p, deletedIds) &&
                    !remoteIds.contains(p.id) &&
                    !remoteCodes.contains(p.projectId) &&
                    !remoteProjects.any(
                      (r) =>
                          r.name.trim().toLowerCase() ==
                          p.name.trim().toLowerCase(),
                    ),
              )
              .toList();

      state = [...mergedProjects, ...localOnly];
      await _persistProjects();
      markFetchCompleted();
    } catch (_) {
      markFetchFailed();
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
    final generatedId =
        'PRJ-${DateTime.now().year}-${uniqueMicro.toString().padLeft(6, '0')}';
    final netRevenue =
        taxStatus == TaxStatus.included
            ? grossProjectValue * (1 - taxRate)
            : grossProjectValue;
    final receivable = grossProjectValue - amountReceived;

    final effectiveTeamMembers =
        <String>{
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

    // Add project assignment record to state for local reference
    for (final memberId in effectiveTeamMembers) {
      ref
          .read(notificationProvider.notifier)
          .addNotification(
            userId: memberId,
            title: 'Assigned to Project 📁',
            message: 'You have been assigned to project "$name".',
            fullExplanation:
                'You are now assigned as a team member on project "$name". You can track budget, submit claims, and view project details.',
            type: NotificationType.projectAssigned,
            relatedProjectId: newProj.id,
          );
    }

    try {
      final repo = ref.read(projectRepositoryProvider);
      final saved = await repo.createProject(newProj);
      state = [
        for (final p in state)
          if (p.id == newProj.id || p.projectId == newProj.projectId)
            saved
          else
            p,
      ];
      await _persistProjects();
      invalidateCache(); // Force next navigation fetch to sync
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
    await _persistProjects();
    invalidateCache(); // Force next navigation fetch to sync

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
            amountReceivable: (p.grossProjectValue -
                    (p.amountReceived + amount))
                .clamp(0.0, double.infinity),
          )
        else
          p,
    ];
    await _persistProjects();
    invalidateCache();

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
    invalidateCache();

    try {
      final repo = ref.read(projectRepositoryProvider);
      await repo.closeProject(projectId, summary);
    } catch (_) {
      // Offline fallback
    }
  }

  /// Updates the project progress (0% - 100%) and uploads to backend PostgreSQL server.
  Future<void> updateProjectProgress({
    required String projectId,
    required double progressPercentage,
    required String updatedById,
    required String updatedByName,
    String? authorRole,
    String? note,
  }) async {
    final clamped = progressPercentage.clamp(0.0, 100.0);
    final now = DateTime.now();
    ProjectModel? updatedProj;

    state = [
      for (final p in state)
        if (p.id == projectId)
          () {
            final newNotes = [...p.progressNotes];
            if (note != null && note.trim().isNotEmpty) {
              newNotes.insert(
                0,
                ProjectProgressNote(
                  id: 'note_${DateTime.now().millisecondsSinceEpoch}',
                  projectId: projectId,
                  progressPercentage: clamped,
                  note: note.trim(),
                  authorId: updatedById,
                  authorName: updatedByName,
                  authorRole: authorRole ?? 'Staff',
                  createdAt: now,
                ),
              );
            }
            final u = p.copyWith(
              progressPercentage: clamped,
              progressUpdatedAt: now,
              progressUpdatedById: updatedById,
              progressUpdatedByName: updatedByName,
              progressNotes: newNotes,
            );
            updatedProj = u;
            return u;
          }()
        else
          p,
    ];
    await _persistProjects();
    invalidateCache();

    if (updatedProj != null) {
      try {
        final repo = ref.read(projectRepositoryProvider);
        await repo.updateProject(updatedProj!);
      } catch (_) {}
    }
  }

  /// Adds a standalone progress note / activity log for a project
  Future<void> addProgressNote({
    required String projectId,
    required String note,
    required String authorId,
    required String authorName,
    String authorRole = 'Project Member',
  }) async {
    final now = DateTime.now();
    ProjectModel? updatedProj;

    state = [
      for (final p in state)
        if (p.id == projectId)
          () {
            final newNotes = [
              ProjectProgressNote(
                id: 'note_${DateTime.now().millisecondsSinceEpoch}',
                projectId: projectId,
                progressPercentage: p.progressPercentage,
                note: note.trim(),
                authorId: authorId,
                authorName: authorName,
                authorRole: authorRole,
                createdAt: now,
              ),
              ...p.progressNotes,
            ];
            final u = p.copyWith(
              progressNotes: newNotes,
            );
            updatedProj = u;
            return u;
          }()
        else
          p,
    ];
    await _persistProjects();
    invalidateCache();

    if (updatedProj != null) {
      try {
        final repo = ref.read(projectRepositoryProvider);
        await repo.updateProject(updatedProj!);
      } catch (_) {}
    }
  }

  /// Assigns a member to project and uploads to backend PostgreSQL server.
  Future<void> assignMemberToProject(String projectId, String memberId) async {
    ProjectModel? updatedProj;
    state = [
      for (final p in state)
        if (p.id == projectId)
          () {
            if (p.teamMemberIds.contains(memberId)) return p;
            final updatedTeam = [...p.teamMemberIds, memberId];
            final u = p.copyWith(teamMemberIds: updatedTeam);
            updatedProj = u;
            return u;
          }()
        else
          p,
    ];
    await _persistProjects();
    invalidateCache();

    if (updatedProj != null) {
      ref
          .read(notificationProvider.notifier)
          .addNotification(
            userId: memberId,
            title: 'Assigned to Project 📁',
            message:
                'You have been assigned to project "${updatedProj!.name}".',
            fullExplanation:
                'You are now assigned as a team member on project "${updatedProj!.name}". You can track budget, submit claims, and view project details.',
            type: NotificationType.projectAssigned,
            relatedProjectId: updatedProj!.id,
          );

      try {
        final repo = ref.read(projectRepositoryProvider);
        await repo.updateProject(updatedProj!);
      } catch (_) {}
    }
  }

  /// Unassigns a member from project and uploads to backend PostgreSQL server.
  Future<void> unassignMemberFromProject(
    String projectId,
    String memberId,
  ) async {
    ProjectModel? updatedProj;
    state = [
      for (final p in state)
        if (p.id == projectId)
          () {
            final updatedTeam =
                p.teamMemberIds.where((id) => id != memberId).toList();
            final u = p.copyWith(teamMemberIds: updatedTeam);
            updatedProj = u;
            return u;
          }()
        else
          p,
    ];
    await _persistProjects();
    invalidateCache();

    if (updatedProj != null) {
      try {
        final repo = ref.read(projectRepositoryProvider);
        await repo.updateProject(updatedProj!);
      } catch (_) {}
    }
  }

  /// Deletes a project from local state and remote backend database.
  Future<void> deleteProject(String projectId) async {
    final candidateIds = <String>{
      projectId.trim(),
      projectId.trim().toLowerCase(),
    };

    for (final p in state) {
      if (p.id == projectId ||
          p.projectId == projectId ||
          p.id.toLowerCase() == projectId.toLowerCase() ||
          p.projectId.toLowerCase() == projectId.toLowerCase() ||
          p.name.trim().toLowerCase() == projectId.trim().toLowerCase()) {
        if (p.id.isNotEmpty) {
          candidateIds.add(p.id);
          candidateIds.add(p.id.toLowerCase());
        }
        if (p.projectId.isNotEmpty) {
          candidateIds.add(p.projectId);
          candidateIds.add(p.projectId.toLowerCase());
        }
        if (p.name.isNotEmpty) {
          candidateIds.add(p.name.trim().toLowerCase());
        }
      }
    }

    await _recordDeletedProjectIds(candidateIds);

    state = state.where((p) => !_isProjectDeleted(p, candidateIds)).toList();
    await _persistProjects();
    invalidateCache();

    try {
      final repo = ref.read(projectRepositoryProvider);
      for (final id in candidateIds) {
        try {
          await repo.deleteProject(id);
        } catch (_) {}
      }
    } catch (_) {}
  }
}

final projectProvider = NotifierProvider<ProjectNotifier, List<ProjectModel>>(
  ProjectNotifier.new,
);
