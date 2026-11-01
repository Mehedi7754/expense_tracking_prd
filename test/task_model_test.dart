import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracking_prd/models/task_model.dart';

void main() {
  test('task model reads persisted todo status and all assignees', () {
    final task = TaskModel.fromJson({
      'id': 'task-1',
      'project_id': 'project-1',
      'title': 'Field survey',
      'description': '',
      'assignee_id': 'user-1',
      'assignee_name': 'Alex',
      'assignees': [
        {'id': 'user-1', 'name': 'Alex'},
        {'id': 'user-2', 'name': 'Sam'},
      ],
      'due_date': '2026-11-10',
      'status': 'todo',
      'priority': 'high',
    });

    expect(task.status, TaskStatus.todo);
    expect(task.assigneeIds, ['user-1', 'user-2']);
  });
}
