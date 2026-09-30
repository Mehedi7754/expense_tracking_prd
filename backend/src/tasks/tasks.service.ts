import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';

@Injectable()
export class TasksService {
  constructor(private readonly db: DatabaseService) {}

  async findAll(projectId?: string) {
    let sql = `
      SELECT t.*, u.full_name as assignee_name
      FROM tasks t
      LEFT JOIN users u ON u.id = t.assignee_id
    `;
    const params: any[] = [];
    if (projectId) {
      sql += ' WHERE t.project_id = $1';
      params.push(projectId);
    }
    sql += ' ORDER BY t.due_date ASC';

    const res = await this.db.query(sql, params);
    return res.rows.map((r) => ({
      id: r.id,
      projectId: r.project_id,
      title: r.title,
      description: r.description,
      assigneeId: r.assignee_id,
      assigneeName: r.assignee_name || 'Unassigned',
      dueDate: r.due_date,
      status: r.status,
      budgetLine: r.budget_line,
    }));
  }

  async create(data: any, user?: any) {
    const assigneeId = data.assigneeId || data.assignee_id || user?.id;
    const res = await this.db.query(
      `INSERT INTO tasks (project_id, title, description, assignee_id, due_date, status, budget_line)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [
        data.projectId || data.project_id,
        data.title,
        data.description || '',
        assigneeId,
        data.dueDate || data.due_date || new Date().toISOString().split('T')[0],
        data.status || 'in_progress',
        data.budgetLine || data.budget_line,
      ],
    );
    const r = res.rows[0];
    return {
      id: r.id,
      projectId: r.project_id,
      title: r.title,
      description: r.description,
      assigneeId: r.assignee_id,
      dueDate: r.due_date,
      status: r.status,
      budgetLine: r.budget_line,
    };
  }
}
