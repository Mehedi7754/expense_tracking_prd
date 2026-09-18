enum TaskStatus {
  inProgress,
  completed;

  String get displayName {
    switch (this) {
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.completed:
        return 'Completed';
    }
  }
}

class TaskModel {
  final String id;
  final String projectId;
  final String title;
  final String description;
  final String assigneeId;
  final String assigneeName;
  final DateTime dueDate;
  final TaskStatus status;
  final String? budgetLine;

  const TaskModel({
    required this.id,
    required this.projectId,
    required this.title,
    required this.description,
    required this.assigneeId,
    required this.assigneeName,
    required this.dueDate,
    this.status = TaskStatus.inProgress,
    this.budgetLine,
  });

  TaskModel copyWith({
    String? id,
    String? projectId,
    String? title,
    String? description,
    String? assigneeId,
    String? assigneeName,
    DateTime? dueDate,
    TaskStatus? status,
    String? budgetLine,
  }) {
    return TaskModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      description: description ?? this.description,
      assigneeId: assigneeId ?? this.assigneeId,
      assigneeName: assigneeName ?? this.assigneeName,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      budgetLine: budgetLine ?? this.budgetLine,
    );
  }
}
