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
    let st = (data.status || 'in_progress').toString().toLowerCase();
    if (st.includes('progress')) st = 'in_progress';
    else if (st.includes('complete')) st = 'completed';

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
        st,
        data.budgetLine || data.budget_line,
      ],
    );
    const r = res.rows[0];

    let assigneeName = 'Unassigned';
    if (r.assignee_id) {
      const uRes = await this.db.query('SELECT full_name FROM users WHERE id = $1', [r.assignee_id]);
      if (uRes.rows.length) assigneeName = uRes.rows[0].full_name;
    }

    return {
      id: r.id,
      projectId: r.project_id,
      title: r.title,
      description: r.description,
      assigneeId: r.assignee_id,
      assigneeName: assigneeName,
      dueDate: r.due_date,
      status: r.status,
      budgetLine: r.budget_line,
    };
  }

  async update(id: string, data: any) {
    const fields: string[] = [];
    const values: any[] = [];
    let idx = 1;

    if (data.status !== undefined) {
      let st = (data.status || 'in_progress').toString().toLowerCase();
      if (st.includes('progress')) st = 'in_progress';
      else if (st.includes('complete')) st = 'completed';
      fields.push(`status = $${idx++}`);
      values.push(st);
    }
    if (data.title !== undefined) {
      fields.push(`title = $${idx++}`);
      values.push(data.title);
    }
    if (data.description !== undefined) {
      fields.push(`description = $${idx++}`);
      values.push(data.description);
    }
    if (data.dueDate || data.due_date) {
      fields.push(`due_date = $${idx++}`);
      values.push(data.dueDate || data.due_date);
    }

    if (fields.length > 0) {
      values.push(id);
      await this.db.query(`UPDATE tasks SET ${fields.join(', ')} WHERE id = $${idx}`, values);
    }

    const res = await this.db.query(
      `SELECT t.*, u.full_name as assignee_name
       FROM tasks t
       LEFT JOIN users u ON u.id = t.assignee_id
       WHERE t.id = $1`,
      [id],
    );
    if (!res.rows.length) {
      return null;
    }
    const r = res.rows[0];
    return {
      id: r.id,
      projectId: r.project_id,
      title: r.title,
      description: r.description,
      assigneeId: r.assignee_id,
      assigneeName: r.assignee_name || 'Unassigned',
      dueDate: r.due_date,
      status: r.status,
      budgetLine: r.budget_line,
    };
  }
}
