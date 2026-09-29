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
    try {
      final repo = ref.read(taskRepositoryProvider);
      final tasks = await repo.getTasks(projectId: projectId, assigneeId: assigneeId);
      state = tasks;
    } catch (_) {
      // Keep existing state on network disconnect
    }
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
    required DateTime dueDate,
    String? budgetLine,
  }) async {
    final newTask = TaskModel(
      id: 'tsk_${DateTime.now().microsecondsSinceEpoch}',
      projectId: projectId,
      title: title,
      description: description,
      assigneeId: assigneeId,
      assigneeName: assigneeName,
      dueDate: dueDate,
      status: TaskStatus.inProgress,
      budgetLine: budgetLine,
    );

    // Optimistic local update
    state = [...state, newTask];

    try {
      final repo = ref.read(taskRepositoryProvider);
      final saved = await repo.createTask(newTask);
      state = [
        for (final t in state)
          if (t.id == newTask.id) saved else t,
      ];
      return saved;
    } catch (_) {
      return newTask;
    }
  }

  Future<void> updateTask(TaskModel updated) async {
    state = [
      for (final t in state)
        if (t.id == updated.id) updated else t,
    ];

    try {
      final repo = ref.read(taskRepositoryProvider);
      await repo.updateTask(updated);
    } catch (_) {
      // Offline fallback
    }
  }

  Future<void> toggleTaskComplete(String taskId) async {
    final current = state.firstWhere((t) => t.id == taskId);
    final updated = current.copyWith(
      status: current.status == TaskStatus.completed
          ? TaskStatus.inProgress
          : TaskStatus.completed,
    );

    state = [
      for (final t in state)
        if (t.id == taskId) updated else t,
    ];

    try {
      final repo = ref.read(taskRepositoryProvider);
      await repo.updateTask(updated);
    } catch (_) {
      // Offline fallback
    }
  }
}

final taskProvider = NotifierProvider<TaskNotifier, List<TaskModel>>(TaskNotifier.new);
