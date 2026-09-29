import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/project_model.dart';

class ProjectRepository {
  final ApiClient _client;

  ProjectRepository(this._client);

  Future<List<ProjectModel>> getProjects() async {
    final response = await _client.get(ApiEndpoints.projects);

    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map(ProjectModel.fromJson)
          .toList();
    } else if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map(ProjectModel.fromJson)
          .toList();
    }

    return const [];
  }

  Future<ProjectModel> getProjectById(String id) async {
    final response = await _client.get(ApiEndpoints.projectById(id));
    final data = response is Map<String, dynamic> && response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response as Map<String, dynamic>;
    return ProjectModel.fromJson(data);
  }

  Future<ProjectModel> createProject(ProjectModel project) async {
    final response = await _client.post(
      ApiEndpoints.projects,
      body: project.toJson(),
    );

    final data = response is Map<String, dynamic> && response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response as Map<String, dynamic>;
    return ProjectModel.fromJson(data);
  }

  Future<ProjectModel> updateProject(ProjectModel project) async {
    final response = await _client.put(
      ApiEndpoints.projectById(project.id),
      body: project.toJson(),
    );

    final data = response is Map<String, dynamic> && response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response as Map<String, dynamic>;
    return ProjectModel.fromJson(data);
  }

  Future<RevenueEntry> addRevenue(String projectId, RevenueEntry entry) async {
    final response = await _client.post(
      ApiEndpoints.projectRevenues(projectId),
      body: entry.toJson(),
    );

    final data = response is Map<String, dynamic> && response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response as Map<String, dynamic>;
    return RevenueEntry.fromJson(data);
  }

  Future<ProjectModel> closeProject(String projectId, ProjectFinancialSummary summary) async {
    final response = await _client.post(
      ApiEndpoints.closeProject(projectId),
      body: summary.toJson(),
    );

    final data = response is Map<String, dynamic> && response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response as Map<String, dynamic>;
    return ProjectModel.fromJson(data);
  }
}

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(ref.watch(apiClientProvider));
});
