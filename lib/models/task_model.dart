enum TaskStatus {
  todo,
  inProgress,
  completed;

  String get displayName {
    switch (this) {
      case TaskStatus.todo:
        return 'To do';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.completed:
        return 'Completed';
    }
  }

  String get dbValue {
    switch (this) {
      case TaskStatus.todo:
        return 'todo';
      case TaskStatus.inProgress:
        return 'in_progress';
      case TaskStatus.completed:
        return 'completed';
    }
  }

  static TaskStatus fromString(String val) {
    switch (val
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('_', '')
        .replaceAll('-', '')) {
      case 'todo':
      case 'notstarted':
        return TaskStatus.todo;
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
  final List<String> assigneeIds;
  final List<String> assigneeNames;
  final DateTime dueDate;
  final TaskStatus status;
  final String priority;
  final String? budgetLine;

  const TaskModel({
    required this.id,
    required this.projectId,
    required this.title,
    required this.description,
    required this.assigneeId,
    required this.assigneeName,
    this.assigneeIds = const [],
    this.assigneeNames = const [],
    required this.dueDate,
    this.status = TaskStatus.inProgress,
    this.priority = 'medium',
    this.budgetLine,
  });

  TaskModel copyWith({
    String? id,
    String? projectId,
    String? title,
    String? description,
    String? assigneeId,
    String? assigneeName,
    List<String>? assigneeIds,
    List<String>? assigneeNames,
    DateTime? dueDate,
    TaskStatus? status,
    String? priority,
    String? budgetLine,
  }) {
    return TaskModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      description: description ?? this.description,
      assigneeId: assigneeId ?? this.assigneeId,
      assigneeName: assigneeName ?? this.assigneeName,
      assigneeIds: assigneeIds ?? this.assigneeIds,
      assigneeNames: assigneeNames ?? this.assigneeNames,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      budgetLine: budgetLine ?? this.budgetLine,
    );
  }

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    final statusStr = (json['status'] ?? 'inProgress').toString();
    final rawAssignees =
        json['assignees'] is List ? json['assignees'] as List : const [];
    final assignees = rawAssignees.whereType<Map>().toList();
    final primaryId =
        (json['assignee_id'] ?? json['assigneeId'] ?? '').toString();
    final primaryName =
        (json['assignee_name'] ?? json['assigneeName'] ?? '').toString();
    final assigneeIds =
        assignees
            .map((a) => (a['id'] ?? '').toString())
            .where((id) => id.isNotEmpty)
            .toList();
    final assigneeNames =
        assignees
            .map((a) => (a['name'] ?? a['full_name'] ?? '').toString())
            .where((name) => name.isNotEmpty)
            .toList();
    if (assigneeIds.isEmpty && primaryId.isNotEmpty) assigneeIds.add(primaryId);
    if (assigneeNames.isEmpty && primaryName.isNotEmpty) {
      assigneeNames.add(primaryName);
    }
    return TaskModel(
      id: (json['id'] ?? '').toString(),
      projectId: (json['project_id'] ?? json['projectId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      assigneeId:
          primaryId.isEmpty && assigneeIds.isNotEmpty
              ? assigneeIds.first
              : primaryId,
      assigneeName:
          primaryName.isEmpty && assigneeNames.isNotEmpty
              ? assigneeNames.first
              : primaryName,
      assigneeIds: assigneeIds,
      assigneeNames: assigneeNames,
      dueDate:
          json['due_date'] != null
              ? DateTime.tryParse(json['due_date'].toString()) ?? DateTime.now()
              : (json['dueDate'] != null
                  ? DateTime.tryParse(json['dueDate'].toString()) ??
                      DateTime.now()
                  : DateTime.now()),
      status: TaskStatus.fromString(statusStr),
      priority: (json['priority'] ?? 'medium').toString(),
      budgetLine:
          json['budget_line']?.toString() ?? json['budgetLine']?.toString(),
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
      'assigneeIds': assigneeIds.isEmpty ? [assigneeId] : assigneeIds,
      'due_date': dueDate.toIso8601String(),
      'status': status.dbValue,
      'priority': priority,
      if (budgetLine != null) 'budget_line': budgetLine,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
