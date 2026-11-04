class ReportFilters {
  const ReportFilters({
    this.from,
    this.to,
    this.projectId,
    this.status,
    this.category,
    this.userId,
    this.search,
  });

  final String? from;
  final String? to;
  final String? projectId;
  final String? status;
  final String? category;
  final String? userId;
  final String? search;

  ReportFilters copyWith({
    String? from,
    String? to,
    String? projectId,
    String? status,
    String? category,
    String? userId,
    String? search,
    bool clearFrom = false,
    bool clearTo = false,
    bool clearProject = false,
    bool clearStatus = false,
    bool clearCategory = false,
    bool clearUser = false,
    bool clearSearch = false,
  }) => ReportFilters(
    from: clearFrom ? null : (from ?? this.from),
    to: clearTo ? null : (to ?? this.to),
    projectId: clearProject ? null : (projectId ?? this.projectId),
    status: clearStatus ? null : (status ?? this.status),
    category: clearCategory ? null : (category ?? this.category),
    userId: clearUser ? null : (userId ?? this.userId),
    search: clearSearch ? null : (search ?? this.search),
  );
}

List<Map<String, dynamic>> filterReportRows(
  List<Map<String, dynamic>> rows,
  ReportFilters filters,
) {
  String first(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return '';
  }

  final query = filters.search?.trim().toLowerCase() ?? '';
  return rows.where((row) {
    final date =
        first(row, [
          'date',
          'createdAt',
          'created_at',
          'startDate',
          'start_date',
          'dueDate',
          'due_date',
        ]).split('T').first;
    if (filters.from != null &&
        (date.isEmpty || date.compareTo(filters.from!) < 0))
      return false;
    if (filters.to != null && (date.isEmpty || date.compareTo(filters.to!) > 0))
      return false;
    if (filters.projectId != null &&
        filters.projectId != 'all' &&
        first(row, ['projectId', 'project_id']) != filters.projectId)
      return false;
    if (filters.status != null &&
        filters.status != 'all' &&
        first(row, [
              'status',
              'approvalStatus',
              'approval_status',
              'leaveStatus',
              'leave_status',
            ]).toLowerCase() !=
            filters.status!.toLowerCase())
      return false;
    if (filters.category != null &&
        filters.category != 'all' &&
        first(row, [
              'category',
              'categoryName',
              'category_name',
              'leaveType',
              'leave_type',
              'workLocation',
            ]).toLowerCase() !=
            filters.category!.toLowerCase())
      return false;
    if (filters.userId != null && filters.userId != 'all') {
      final id = first(row, [
        'userId',
        'user_id',
        'employeeId',
        'employee_id',
        'assigneeId',
        'assignee_id',
      ]);
      final ids = (row['assigneeIds'] as List? ?? const []).map(
        (value) => value.toString(),
      );
      final members = row['assignees'] as List? ?? const [];
      final memberMatch = members.any(
        (entry) =>
            entry is Map &&
            (entry['id'] ?? entry['userId'] ?? entry['user_id']).toString() ==
                filters.userId,
      );
      if (id != filters.userId && !ids.contains(filters.userId) && !memberMatch)
        return false;
    }
    if (query.isNotEmpty &&
        !row.values
            .map((value) => value?.toString() ?? '')
            .join(' ')
            .toLowerCase()
            .contains(query))
      return false;
    return true;
  }).toList();
}
