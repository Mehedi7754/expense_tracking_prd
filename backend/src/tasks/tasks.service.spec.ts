import { TasksService } from './tasks.service';
import { DatabaseService } from '../database/database.service';
import { BadRequestException, ForbiddenException } from '@nestjs/common';

describe('TasksService access filters', () => {
  let service: TasksService;
  let db: { query: jest.Mock; transaction: jest.Mock };
  let notifications: { create: jest.Mock };

  beforeEach(() => {
    db = {
      query: jest.fn().mockResolvedValue({ rows: [] }),
      transaction: jest.fn(),
    };
    notifications = { create: jest.fn() };
    service = new TasksService(db as unknown as DatabaseService, notifications as any);
  });

  it('limits project members to their own assigned tasks even if they request another assignee', async () => {
    await service.findAll(undefined, 'another-user', { id: 'member-1', role: 'project_member' });

    expect(db.query.mock.calls[0][0]).toContain('task_assignees');
    expect(db.query.mock.calls[0][1]).toEqual(['member-1']);
  });

  it('denies task access to roles outside the task permission plan', async () => {
    await expect(service.findAll(undefined, undefined, { id: 'viewer-1', role: 'viewer' }))
      .rejects.toBeInstanceOf(ForbiddenException);
    expect(db.query).not.toHaveBeenCalled();
  });

  it('loads task assignees in the same query instead of one extra query per task', async () => {
    db.query.mockResolvedValueOnce({ rows: [
      { id: 'task-1', title: 'One', assignee_id: 'member-1', assignees: [{ id: 'member-1', name: 'Member One' }] },
      { id: 'task-2', title: 'Two', assignee_id: 'member-2', assignees: [{ id: 'member-2', name: 'Member Two' }] },
    ] });

    const tasks = await service.findAll(undefined, undefined, { id: 'admin-1', role: 'main_admin' });

    expect(db.query).toHaveBeenCalledTimes(1);
    expect(tasks.map((task) => task.assignees[0].id)).toEqual(['member-1', 'member-2']);
  });

  it('rejects inactive and read-only users as task assignees', async () => {
    await expect(service.create({
      projectId: 'project-1',
      title: 'Review project plan',
      dueDate: '2026-11-10',
      assigneeIds: ['viewer-1'],
    }, { id: 'admin-1', role: 'main_admin' })).rejects.toBeInstanceOf(BadRequestException);

    expect(db.query.mock.calls[0][0]).toContain("role IN ('main_admin', 'project_manager', 'project_member')");
  });

  it('persists every assignee and creates a notification for each assigned member', async () => {
    const taskRow = {
      id: 'task-1',
      project_id: 'project-1',
      title: 'Review project plan',
      description: '',
      assignee_id: 'member-1',
      assignee_name: 'Member One',
      due_date: '2026-11-10',
      status: 'todo',
      priority: 'medium',
      budget_line: null,
    };
    const client = { query: jest.fn()
      .mockResolvedValueOnce({ rows: [{ id: 'task-1' }] })
      .mockResolvedValue({ rows: [] }) };
    db.query
      .mockResolvedValueOnce({ rows: [{ id: 'member-1' }, { id: 'member-2' }] })
      .mockResolvedValueOnce({ rows: [taskRow] })
      .mockResolvedValueOnce({ rows: [
        { id: 'member-1', full_name: 'Member One' },
        { id: 'member-2', full_name: 'Member Two' },
      ] });
    db.transaction.mockImplementation(async (callback: (tx: typeof client) => Promise<unknown>) => callback(client));

    const created = await service.create({
      projectId: 'project-1',
      title: 'Review project plan',
      dueDate: '2026-11-10',
      assigneeIds: ['member-1', 'member-2'],
    }, { id: 'admin-1', name: 'Admin', role: 'main_admin' });

    expect(created.assignees.map((assignee) => assignee.id)).toEqual(['member-1', 'member-2']);
    expect(client.query).toHaveBeenCalledTimes(3);
    expect(client.query.mock.calls[1]).toEqual([
      'INSERT INTO task_assignees (task_id, user_id) VALUES ($1, $2)',
      ['task-1', 'member-1'],
    ]);
    expect(client.query.mock.calls[2][1]).toEqual(['task-1', 'member-2']);
    expect(notifications.create).toHaveBeenCalledTimes(2);
    expect(notifications.create.mock.calls.map(([notification]) => notification.userId)).toEqual(['member-1', 'member-2']);
  });
});
