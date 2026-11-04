import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracking_prd/core/utils/report_filters.dart';

void main() {
  test('filters report rows by date, project, status, employee and search', () {
    final rows = [
      {
        'date': '2026-10-14',
        'projectId': 'p1',
        'status': 'approved',
        'employeeId': 'u1',
        'title': 'Site inspection',
      },
      {
        'date': '2026-10-18',
        'projectId': 'p2',
        'status': 'pending',
        'employeeId': 'u2',
        'title': 'Office supplies',
      },
    ];

    final result = filterReportRows(
      rows,
      const ReportFilters(
        from: '2026-10-10',
        to: '2026-10-15',
        projectId: 'p1',
        status: 'approved',
        userId: 'u1',
        search: 'inspection',
      ),
    );

    expect(result, hasLength(1));
    expect(result.single['title'], 'Site inspection');
  });

  test('matches a selected employee in multi-assignee rows', () {
    final result = filterReportRows(
      [
        {
          'date': '2026-10-14',
          'assigneeIds': ['u1', 'u2'],
        },
      ],
      const ReportFilters(userId: 'u2'),
    );

    expect(result, hasLength(1));
  });
}
