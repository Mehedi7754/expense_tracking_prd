import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/task_model.dart';

class TaskRepository {
  final ApiClient _client;

  TaskRepository(this._client);

  Future<List<TaskModel>> getTasks({String? projectId, String? assigneeId}) async {
    final queryParams = <String, dynamic>{
      if (projectId != null) 'project_id': projectId,
      if (assigneeId != null) 'assignee_id': assigneeId,
    };

    final response = await _client.get(
      ApiEndpoints.tasks,
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );

    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map(TaskModel.fromJson)
          .toList();
    } else if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map(TaskModel.fromJson)
          .toList();
    }

    return const [];
  }

  Future<TaskModel> createTask(TaskModel task) async {
    final response = await _client.post(
      ApiEndpoints.tasks,
      body: task.toJson(),
    );

    final data = response is Map<String, dynamic> && response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response as Map<String, dynamic>;
    return TaskModel.fromJson(data);
  }

  Future<TaskModel> updateTask(TaskModel task) async {
    final response = await _client.put(
      ApiEndpoints.taskById(task.id),
      body: task.toJson(),
    );

    final data = response is Map<String, dynamic> && response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response as Map<String, dynamic>;
    return TaskModel.fromJson(data);
  }
}

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(ref.watch(apiClientProvider));
});
