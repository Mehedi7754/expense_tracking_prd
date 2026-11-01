import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { NotificationsService } from '../notifications/notifications.service';

type TaskActor = {
  id: string;
  name?: string;
  role: string;
  assignedProjectIds?: string[];
};

@Injectable()
export class TasksService {
  constructor(
    private readonly db: DatabaseService,
    private readonly notifications: NotificationsService,
  ) {}

  private normalizeStatus(value: unknown): string {
    const status = String(value || '').toLowerCase().replace(/[\s-]+/g, '_');
    if (['todo', 'in_progress', 'completed'].includes(status)) return status;
    throw new BadRequestException('Status must be To do, In progress, or Completed');
  }

  private async mapTask(row: Record<string, any>) {
    let assignees: Array<{ id: string; name: string }>;
    if (row.assignees !== undefined) {
      let members = row.assignees;
      if (typeof members === 'string') {
        try { members = JSON.parse(members); } catch { members = []; }
      }
      assignees = Array.isArray(members) ? members.map((member) => ({ id: member.id, name: member.name || member.full_name || 'Unassigned' })) : [];
    } else {
      const members = await this.db.query(
        'SELECT u.id, u.full_name FROM task_assignees ta JOIN users u ON u.id = ta.user_id WHERE ta.task_id = $1 ORDER BY ta.assigned_at',
        [row.id],
      );
      assignees = members.rows.map((member) => ({ id: member.id, name: member.full_name }));
    }
    if (!assignees.length && row.assignee_id) {
      assignees.push({ id: row.assignee_id, name: row.assignee_name || 'Unassigned' });
    }
    return {
      id: row.id,
      projectId: row.project_id,
      projectName: row.project_name,
      title: row.title,
      description: row.description,
      assigneeId: row.assignee_id,
      assigneeName: assignees[0]?.name || row.assignee_name || 'Unassigned',
      assignees,
      dueDate: row.due_date,
      status: row.status,
      priority: row.priority || 'medium',
      budgetLine: row.budget_line,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }

  async findAll(projectId: string | undefined, assigneeId: string | undefined, actor: TaskActor) {
    if (!['main_admin', 'project_manager', 'project_member'].includes(actor.role)) {
      throw new ForbiddenException('Your role cannot access task management');
    }

    const conditions: string[] = [];
    const values: unknown[] = [];
    const add = (value: unknown) => {
      values.push(value);
      return '$' + values.length;
    };

    if (actor.role === 'project_member') {
      const id = add(actor.id);
      conditions.push('(t.assignee_id = ' + id + ' OR EXISTS (SELECT 1 FROM task_assignees ta WHERE ta.task_id = t.id AND ta.user_id = ' + id + '))');
    } else if (actor.role === 'project_manager') {
      const allowed = actor.assignedProjectIds || [];
      if (!allowed.length) return [];
      conditions.push('t.project_id = ANY(' + add(allowed) + '::uuid[])');
      if (assigneeId) {
        const id = add(assigneeId);
        conditions.push('(t.assignee_id = ' + id + ' OR EXISTS (SELECT 1 FROM task_assignees ta WHERE ta.task_id = t.id AND ta.user_id = ' + id + '))');
      }
    } else if (assigneeId) {
      const id = add(assigneeId);
      conditions.push('(t.assignee_id = ' + id + ' OR EXISTS (SELECT 1 FROM task_assignees ta WHERE ta.task_id = t.id AND ta.user_id = ' + id + '))');
    }
    if (projectId) conditions.push('t.project_id = ' + add(projectId));

    const sql =
      `SELECT t.*, u.full_name AS assignee_name, p.name AS project_name,
              COALESCE(task_members.assignees, '[]'::json) AS assignees ` +
      'FROM tasks t LEFT JOIN users u ON u.id = t.assignee_id ' +
      'LEFT JOIN projects p ON p.id = t.project_id ' +
      `LEFT JOIN LATERAL (
         SELECT json_agg(json_build_object('id', member.id, 'name', member.full_name) ORDER BY ta.assigned_at) AS assignees
         FROM task_assignees ta JOIN users member ON member.id = ta.user_id WHERE ta.task_id = t.id
       ) task_members ON TRUE ` +
      (conditions.length ? 'WHERE ' + conditions.join(' AND ') + ' ' : '') +
      'ORDER BY t.due_date ASC, t.created_at DESC';
    const result = await this.db.query(sql, values);
    return Promise.all(result.rows.map((row) => this.mapTask(row)));
  }

  private async assertProjectAccess(projectId: string, actor: TaskActor) {
    if (actor.role === 'main_admin') return;
    if (actor.role !== 'project_manager' || !(actor.assignedProjectIds || []).includes(projectId)) {
      throw new ForbiddenException('You can manage tasks only in projects assigned to you');
    }
  }

  private normalizeAssigneeIds(data: any, actor: TaskActor): string[] {
    const raw = data.assigneeIds ?? data.assignee_ids ?? [data.assigneeId ?? data.assignee_id ?? actor.id];
    const ids = Array.isArray(raw) ? raw : [raw];
    const unique = [...new Set(ids.map((value) => String(value || '').trim()).filter(Boolean))];
    if (!unique.length) throw new BadRequestException('Select at least one task assignee');
    return unique;
  }

  private async assertAssigneesExist(ids: string[]) {
    const result = await this.db.query(
      "SELECT id FROM users WHERE id = ANY($1::uuid[]) AND is_active = TRUE AND role IN ('main_admin', 'project_manager', 'project_member')",
      [ids],
    );
    if (result.rows.length !== ids.length) {
      throw new BadRequestException('Choose active administrators, managers, or project members as assignees');
    }
  }

  async create(data: any, actor: TaskActor) {
    const projectId = String(data.projectId || data.project_id || '');
    const title = String(data.title || '').trim();
    const dueDate = data.dueDate || data.due_date;
    if (!projectId || !title || !dueDate) {
      throw new BadRequestException('Project, task title, and due date are required');
    }
    await this.assertProjectAccess(projectId, actor);
    const assigneeIds = this.normalizeAssigneeIds(data, actor);
    await this.assertAssigneesExist(assigneeIds);
    const status = this.normalizeStatus(data.status || 'todo');
    const priority = String(data.priority || 'medium').toLowerCase();
    if (!['low', 'medium', 'high', 'important'].includes(priority)) {
      throw new BadRequestException('Choose a valid task priority');
    }

    const taskId = await this.db.transaction(async (client) => {
      const inserted = await client.query(
        'INSERT INTO tasks (project_id, title, description, assignee_id, due_date, status, budget_line, priority) ' +
        'VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING id',
        [projectId, title, String(data.description || ''), assigneeIds[0], dueDate, status, data.budgetLine || data.budget_line || null, priority],
      );
      const id = inserted.rows[0].id;
      for (const userId of assigneeIds) {
        await client.query(
          'INSERT INTO task_assignees (task_id, user_id) VALUES ($1, $2)',
          [id, userId],
        );
      }
      return id;
    });

    const result = await this.db.query(
      'SELECT t.*, u.full_name AS assignee_name, p.name AS project_name FROM tasks t ' +
      'LEFT JOIN users u ON u.id = t.assignee_id LEFT JOIN projects p ON p.id = t.project_id WHERE t.id = $1',
      [taskId],
    );
    const task = await this.mapTask(result.rows[0]);
    for (const assignee of task.assignees) {
      if (assignee.id === actor.id) continue;
      await this.notifications.create({
        userId: assignee.id,
        title: 'Task assigned',
        message: actor.name ? actor.name + ' assigned you "' + task.title + '"' : 'You were assigned "' + task.title + '"',
        type: 'task_assigned',
        relatedProjectId: projectId,
        relatedTaskId: task.id,
        actorId: actor.id,
        actorName: actor.name,
      });
    }
    return task;
  }

  async update(id: string, data: any, actor: TaskActor) {
    const currentResult = await this.db.query(
      'SELECT t.*, p.name AS project_name FROM tasks t LEFT JOIN projects p ON p.id = t.project_id WHERE t.id = $1',
      [id],
    );
    const current = currentResult.rows[0];
    if (!current) throw new NotFoundException('Task not found');

    if (actor.role === 'project_member') {
      const assigned = await this.db.query(
        'SELECT 1 FROM task_assignees WHERE task_id = $1 AND user_id = $2 UNION SELECT 1 FROM tasks WHERE id = $1 AND assignee_id = $2 LIMIT 1',
        [id, actor.id],
      );
      if (!assigned.rows.length) throw new ForbiddenException('You can update only tasks assigned to you');
      const allowed = Object.keys(data).every((key) => key === 'status');
      if (!allowed || data.status === undefined) {
        throw new ForbiddenException('Team members can update task status only');
      }
    } else {
      await this.assertProjectAccess(current.project_id, actor);
    }

    const status = data.status === undefined ? undefined : this.normalizeStatus(data.status);
    const requestedAssignees = actor.role === 'project_member' ? undefined : (
      data.assigneeIds ?? data.assignee_ids ?? (data.assigneeId || data.assignee_id ? [data.assigneeId || data.assignee_id] : undefined)
    );
    const assigneeIds = requestedAssignees === undefined ? undefined : this.normalizeAssigneeIds({ assigneeIds: requestedAssignees }, actor);
    if (assigneeIds) await this.assertAssigneesExist(assigneeIds);
    const priority = data.priority === undefined ? undefined : String(data.priority).toLowerCase();
    if (priority !== undefined && !['low', 'medium', 'high', 'important'].includes(priority)) {
      throw new BadRequestException('Choose a valid task priority');
    }

    const fields: string[] = [];
    const values: unknown[] = [];
    const addField = (name: string, value: unknown) => {
      values.push(value);
      fields.push(name + ' = $' + values.length);
    };
    if (status !== undefined) addField('status', status);
    if (data.title !== undefined) addField('title', String(data.title).trim());
    if (data.description !== undefined) addField('description', String(data.description));
    if (data.dueDate !== undefined || data.due_date !== undefined) addField('due_date', data.dueDate || data.due_date);
    if (priority !== undefined) addField('priority', priority);
    if (data.budgetLine !== undefined || data.budget_line !== undefined) addField('budget_line', data.budgetLine || data.budget_line || null);
    if (assigneeIds) addField('assignee_id', assigneeIds[0]);
    if (fields.length || assigneeIds) {
      await this.db.transaction(async (client) => {
        if (fields.length) {
          values.push(id);
          await client.query('UPDATE tasks SET ' + fields.join(', ') + ', updated_at = NOW() WHERE id = $' + values.length, values);
        }
        if (assigneeIds) {
          await client.query('DELETE FROM task_assignees WHERE task_id = $1', [id]);
          for (const userId of assigneeIds) {
            await client.query('INSERT INTO task_assignees (task_id, user_id) VALUES ($1, $2)', [id, userId]);
          }
        }
      });
    }

    const result = await this.db.query(
      'SELECT t.*, u.full_name AS assignee_name, p.name AS project_name FROM tasks t ' +
      'LEFT JOIN users u ON u.id = t.assignee_id LEFT JOIN projects p ON p.id = t.project_id WHERE t.id = $1',
      [id],
    );
    if (!result.rows.length) throw new NotFoundException('Task not found');
    const task = await this.mapTask(result.rows[0]);
    if (actor.role === 'project_member' && status && status !== current.status) {
      const managers = await this.db.query(
        `SELECT DISTINCT u.id, u.full_name FROM project_members pm JOIN users u ON u.id = pm.user_id
         WHERE pm.project_id = $1 AND u.role = 'project_manager' AND u.id <> $2`,
        [current.project_id, actor.id],
      );
      for (const manager of managers.rows) {
        await this.notifications.create({
          userId: manager.id,
          title: 'Task status updated',
          message: (actor.name || 'A team member') + ' moved "' + task.title + '" to ' + status.replace('_', ' ') + '.',
          type: 'task_status_updated',
          relatedProjectId: current.project_id,
          relatedTaskId: task.id,
          actorId: actor.id,
          actorName: actor.name,
        });
      }
    }
    const oldIds = new Set([current.assignee_id]);
    if (assigneeIds) {
      for (const assignee of task.assignees) {
        if (!oldIds.has(assignee.id)) {
          await this.notifications.create({
            userId: assignee.id,
            title: 'Task assigned',
            message: actor.name ? actor.name + ' assigned you "' + task.title + '"' : 'You were assigned "' + task.title + '"',
            type: 'task_assigned',
            relatedProjectId: current.project_id,
            relatedTaskId: task.id,
            actorId: actor.id,
            actorName: actor.name,
          });
        }
      }
    }
    return task;
  }

  async delete(id: string, actor: TaskActor) {
    const current = await this.db.query('SELECT project_id FROM tasks WHERE id = $1', [id]);
    if (!current.rows.length) throw new NotFoundException('Task not found');
    await this.assertProjectAccess(current.rows[0].project_id, actor);
    await this.db.query('DELETE FROM tasks WHERE id = $1', [id]);
    return { success: true };
  }
}
