import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task_model.dart';
import '../repositories/task_repository.dart';

class TaskNotifier extends Notifier<List<TaskModel>> {
  @override
  List<TaskModel> build() {
    // Default clean empty state on startup (no hardcoded demo tasks)
    return const [];
  }

  Future<void> fetchTasks({String? projectId, String? assigneeId}) async {
    final repo = ref.read(taskRepositoryProvider);
    final tasks = await repo.getTasks(
      projectId: projectId,
      assigneeId: assigneeId,
    );
    state = tasks;
  }

  void setTasks(List<TaskModel> tasks) {
    state = tasks;
  }

  Future<TaskModel> addTask({
    required String projectId,
    required String title,
    required String description,
    required String assigneeId,
    required String assigneeName,
    List<String>? assigneeIds,
    required DateTime dueDate,
    String? budgetLine,
    TaskStatus status = TaskStatus.todo,
    String priority = 'medium',
  }) async {
    final newTask = TaskModel(
      id: '',
      projectId: projectId,
      title: title,
      description: description,
      assigneeId: assigneeId,
      assigneeName: assigneeName,
      assigneeIds: assigneeIds ?? [assigneeId],
      assigneeNames: [assigneeName],
      dueDate: dueDate,
      status: status,
      priority: priority,
      budgetLine: budgetLine,
    );

    final repo = ref.read(taskRepositoryProvider);
    final saved = await repo.createTask(newTask);
    state = [...state, saved];
    return saved;
  }

  Future<void> updateTask(TaskModel updated) async {
    final previous = state;
    state = [
      for (final t in state)
        if (t.id == updated.id) updated else t,
    ];

    try {
      final repo = ref.read(taskRepositoryProvider);
      final saved = await repo.updateTask(updated);
      state = [
        for (final t in state)
          if (t.id == updated.id) saved else t,
      ];
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  Future<void> toggleTaskComplete(String taskId) async {
    final current = state.firstWhere((t) => t.id == taskId);
    await updateTaskStatus(
      taskId,
      current.status == TaskStatus.completed
          ? TaskStatus.inProgress
          : TaskStatus.completed,
    );
  }

  Future<void> updateTaskStatus(String taskId, TaskStatus status) async {
    final current = state.firstWhere((t) => t.id == taskId);
    final updated = current.copyWith(status: status);
    final previous = state;
    state = [
      for (final t in state)
        if (t.id == taskId) updated else t,
    ];

    try {
      final repo = ref.read(taskRepositoryProvider);
      final saved = await repo.updateTaskStatus(taskId, status);
      state = [
        for (final t in state)
          if (t.id == taskId) saved else t,
      ];
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}

final taskProvider = NotifierProvider<TaskNotifier, List<TaskModel>>(
  TaskNotifier.new,
);
