import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task_model.dart';

class TaskNotifier extends Notifier<List<TaskModel>> {
  static final List<TaskModel> _initialTasks = [
    TaskModel(
      id: 'tsk_01',
      projectId: 'proj_01',
      title: 'Design System & Token Architecture',
      description: 'Establish typography scale, custom light palette, and token definitions.',
      assigneeId: 'usr_emp_01',
      assigneeName: 'Alex Morgan',
      dueDate: DateTime(2026, 9, 25),
      status: TaskStatus.completed,
      budgetLine: 'Design & UI Assets',
    ),
    TaskModel(
      id: 'tsk_02',
      projectId: 'proj_01',
      title: 'State Management & GoRouter Wiring',
      description: 'Implement Riverpod architecture with role-based routing guards.',
      assigneeId: 'usr_emp_01',
      assigneeName: 'Alex Morgan',
      dueDate: DateTime(2026, 9, 30),
      status: TaskStatus.inProgress,
      budgetLine: 'Frontend Engineering',
    ),
    TaskModel(
      id: 'tsk_03',
      projectId: 'proj_02',
      title: 'Terraform Cluster Provisioning',
      description: 'Automate multi-region AWS EKS deployment scripts.',
      assigneeId: 'usr_emp_01',
      assigneeName: 'Alex Morgan',
      dueDate: DateTime(2026, 10, 15),
      status: TaskStatus.inProgress,
      budgetLine: 'Cloud Infrastructure',
    ),
    TaskModel(
      id: 'tsk_04',
      projectId: 'proj_03',
      title: 'Model Ingestion & Evaluation Suite',
      description: 'Validate data pipelines against edge financial fixtures.',
      assigneeId: 'usr_emp_01',
      assigneeName: 'Alex Morgan',
      dueDate: DateTime(2026, 10, 5),
      status: TaskStatus.inProgress,
      budgetLine: 'Machine Learning',
    ),
  ];

  @override
  List<TaskModel> build() => _initialTasks;

  void addTask({
    required String projectId,
    required String title,
    required String description,
    required String assigneeId,
    required String assigneeName,
    required DateTime dueDate,
    String? budgetLine,
  }) {
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
    state = [...state, newTask];
  }

  void updateTask(TaskModel updated) {
    state = [
      for (final t in state)
        if (t.id == updated.id) updated else t,
    ];
  }

  void toggleTaskComplete(String taskId) {
    state = [
      for (final t in state)
        if (t.id == taskId)
          t.copyWith(
            status: t.status == TaskStatus.completed
                ? TaskStatus.inProgress
                : TaskStatus.completed,
          )
        else
          t,
    ];
  }
}

final taskProvider = NotifierProvider<TaskNotifier, List<TaskModel>>(TaskNotifier.new);
