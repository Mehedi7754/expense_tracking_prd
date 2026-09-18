class RevenueEntry {
  final String id;
  final String projectId;
  final double amount;
  final DateTime date;
  final String note;
  final String createdBy;

  const RevenueEntry({
    required this.id,
    required this.projectId,
    required this.amount,
    required this.date,
    required this.note,
    required this.createdBy,
  });
}

enum ProjectStatus {
  active,
  completed,
  onHold;

  String get displayName {
    switch (this) {
      case ProjectStatus.active:
        return 'Active';
      case ProjectStatus.completed:
        return 'Completed';
      case ProjectStatus.onHold:
        return 'On Hold';
    }
  }
}

class ProjectModel {
  final String id;
  final String name;
  final String description;
  final String client;
  final double budget;
  final double expectedRevenue;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> teamMemberIds;
  final ProjectStatus status;
  final List<RevenueEntry> revenueEntries;

  const ProjectModel({
    required this.id,
    required this.name,
    required this.description,
    required this.client,
    required this.budget,
    required this.expectedRevenue,
    required this.startDate,
    required this.endDate,
    required this.teamMemberIds,
    this.status = ProjectStatus.active,
    this.revenueEntries = const [],
  });

  ProjectModel copyWith({
    String? id,
    String? name,
    String? description,
    String? client,
    double? budget,
    double? expectedRevenue,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? teamMemberIds,
    ProjectStatus? status,
    List<RevenueEntry>? revenueEntries,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      client: client ?? this.client,
      budget: budget ?? this.budget,
      expectedRevenue: expectedRevenue ?? this.expectedRevenue,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      teamMemberIds: teamMemberIds ?? this.teamMemberIds,
      status: status ?? this.status,
      revenueEntries: revenueEntries ?? this.revenueEntries,
    );
  }
}
