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

  static TaskStatus fromString(String val) {
    switch (val.toLowerCase().replaceAll(' ', '').replaceAll('_', '').replaceAll('-', '')) {
      case 'completed':
        return TaskStatus.completed;
      case 'inprogress':
      default:
        return TaskStatus.inProgress;
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

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    final statusStr = (json['status'] ?? 'inProgress').toString();
    return TaskModel(
      id: (json['id'] ?? '').toString(),
      projectId: (json['project_id'] ?? json['projectId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      assigneeId: (json['assignee_id'] ?? json['assigneeId'] ?? '').toString(),
      assigneeName: (json['assignee_name'] ?? json['assigneeName'] ?? '').toString(),
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'].toString()) ?? DateTime.now()
          : (json['dueDate'] != null
              ? DateTime.tryParse(json['dueDate'].toString()) ?? DateTime.now()
              : DateTime.now()),
      status: TaskStatus.fromString(statusStr),
      budgetLine: json['budget_line']?.toString() ?? json['budgetLine']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'title': title,
      'description': description,
      'assignee_id': assigneeId,
      'assignee_name': assigneeName,
      'due_date': dueDate.toIso8601String(),
      'status': status.name,
      if (budgetLine != null) 'budget_line': budgetLine,
    };
  }
}
