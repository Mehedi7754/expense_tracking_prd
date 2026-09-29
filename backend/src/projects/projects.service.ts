import { Injectable, NotFoundException } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';

@Injectable()
export class ProjectsService {
  constructor(private readonly db: DatabaseService) {}

  private mapProjectRow(p: any, revenues: any[] = [], members: any[] = []) {
    return {
      id: p.id,
      projectId: p.project_code,
      name: p.name,
      description: p.description || '',
      client: p.client_name,
      clientId: p.client_id,
      clientType: p.client_type,
      assignmentType: p.assignment_type,
      grossProjectValue: Number(p.gross_project_value),
      taxStatus: p.tax_status,
      taxRate: Number(p.tax_rate),
      expectedNetRevenue: Number(p.expected_net_revenue),
      advanceReceived: Number(p.advance_received),
      amountReceived: Number(p.amount_received),
      amountReceivable: Number(p.amount_receivable),
      budget: Number(p.budget),
      categoryBudgets: typeof p.category_budgets === 'string' ? JSON.parse(p.category_budgets) : p.category_budgets || {},
      estimatedRemainingCost: Number(p.estimated_remaining_cost),
      officeBenefitRate: Number(p.office_benefit_rate),
      startDate: p.start_date,
      endDate: p.end_date,
      status: p.status,
      isClosed: Boolean(p.is_closed),
      closedAt: p.closed_at,
      closingSummary: p.closing_summary,
      teamMemberIds: members.map((m) => m.user_id || m),
      revenueEntries: revenues.map((r) => ({
        id: r.id,
        projectId: r.project_id,
        amount: Number(r.amount),
        date: r.date,
        note: r.note || '',
        createdBy: r.created_by_name || r.created_by || '',
      })),
    };
  }

  async findAll(user: any) {
    const isAdminOrFinance = user.role === 'main_admin' || user.role === 'finance';
    
    let queryText = `
      SELECT p.*,
        COALESCE(
          (SELECT json_agg(json_build_object(
            'id', pr.id, 'project_id', pr.project_id, 'amount', pr.amount,
            'date', pr.date, 'note', pr.note, 'created_by', u.full_name
          ))
          FROM project_revenues pr
          LEFT JOIN users u ON u.id = pr.created_by
          WHERE pr.project_id = p.id),
          '[]'::json
        ) AS revenues,
        COALESCE(
          (SELECT json_agg(pm.user_id)
           FROM project_members pm
           WHERE pm.project_id = p.id),
          '[]'::json
        ) AS team_members
      FROM projects p
    `;

    const params: any[] = [];
    if (!isAdminOrFinance) {
      queryText += ` WHERE EXISTS (SELECT 1 FROM project_members pm WHERE pm.project_id = p.id AND pm.user_id = $1) `;
      params.push(user.id);
    }

    queryText += ` ORDER BY p.created_at DESC `;

    const res = await this.db.query(queryText, params);
    return res.rows.map((row) => this.mapProjectRow(row, row.revenues, row.team_members));
  }

  async findOne(id: string) {
    const res = await this.db.query(
      `SELECT p.*,
        COALESCE(
          (SELECT json_agg(json_build_object(
            'id', pr.id, 'project_id', pr.project_id, 'amount', pr.amount,
            'date', pr.date, 'note', pr.note, 'created_by', u.full_name
          ))
          FROM project_revenues pr
          LEFT JOIN users u ON u.id = pr.created_by
          WHERE pr.project_id = p.id),
          '[]'::json
        ) AS revenues,
        COALESCE(
          (SELECT json_agg(pm.user_id)
           FROM project_members pm
           WHERE pm.project_id = p.id),
          '[]'::json
        ) AS team_members
      FROM projects p
      WHERE p.id::text = $1 OR p.project_code = $1`,
      [id],
    );

    if (!res.rows.length) {
      throw new NotFoundException(`Project not found: ${id}`);
    }

    const row = res.rows[0];
    return this.mapProjectRow(row, row.revenues, row.team_members);
  }

  async create(data: any, createdById: string) {
    return this.db.transaction(async (client) => {
      const gross = Number(data.grossProjectValue || data.gross_project_value || 0);
      const taxRate = Number(data.taxRate || data.tax_rate || 0.1);
      const taxStatus = data.taxStatus || data.tax_status || 'included';
      const netRevenue = taxStatus === 'included' ? gross * (1 - taxRate) : gross;
      const budget = Number(data.budget || gross * 0.85);
      const advanceReceived = Number(data.advanceReceived || data.advance_received || 0);
      const amountReceived = Number(data.amountReceived || data.amount_received || 0);
      const receivable = gross - amountReceived;

      // Project code auto-generation if not supplied
      let projectCode = data.projectId || data.project_code;
      if (!projectCode) {
        const countRes = await client.query('SELECT count(*) FROM projects');
        const num = parseInt(countRes.rows[0].count, 10) + 1;
        projectCode = `PRJ-${new Date().getFullYear()}-${num.toString().padStart(3, '0')}`;
      }

      const projRes = await client.query(
        `INSERT INTO projects (
          project_code, name, description, client_name, client_id, client_type, assignment_type,
          gross_project_value, tax_status, tax_rate, expected_net_revenue,
          advance_received, amount_received, amount_receivable, budget,
          category_budgets, estimated_remaining_cost, office_benefit_rate,
          start_date, end_date, status, created_by
        ) VALUES (
          $1, $2, $3, $4, $5, $6, $7,
          $8, $9, $10, $11,
          $12, $13, $14, $15,
          $16, $17, $18,
          $19, $20, $21, $22
        ) RETURNING *`,
        [
          projectCode,
          data.name,
          data.description || '',
          data.client || data.client_name || 'Client',
          data.clientId || data.client_id || null,
          data.clientType || data.client_type || 'private',
          data.assignmentType || data.assignment_type || 'direct_consultancy',
          gross,
          taxStatus,
          taxRate,
          netRevenue,
          advanceReceived,
          amountReceived,
          receivable > 0 ? receivable : 0,
          budget,
          JSON.stringify(data.categoryBudgets || data.category_budgets || {}),
          Number(data.estimatedRemainingCost || data.estimated_remaining_cost || 0),
          Number(data.officeBenefitRate || data.office_benefit_rate || 0.3),
          data.startDate || data.start_date || new Date().toISOString().split('T')[0],
          data.endDate || data.end_date || new Date().toISOString().split('T')[0],
          data.status || 'ongoing',
          createdById,
        ],
      );

      const created = projRes.rows[0];

      // Insert team members
      const teamMembers: string[] = data.teamMemberIds || data.team_member_ids || [];
      for (const memberId of teamMembers) {
        await client.query(
          `INSERT INTO project_members (project_id, user_id, role_in_project)
           VALUES ($1, $2, 'Member')
           ON CONFLICT DO NOTHING`,
          [created.id, memberId],
        );
      }

      return this.mapProjectRow(created, [], teamMembers);
    });
  }

  async update(id: string, data: any) {
    const fields: string[] = [];
    const values: any[] = [];
    let idx = 1;

    if (data.name !== undefined) {
      fields.push(`name = $${idx++}`);
      values.push(data.name);
    }
    if (data.description !== undefined) {
      fields.push(`description = $${idx++}`);
      values.push(data.description);
    }
    if (data.budget !== undefined) {
      fields.push(`budget = $${idx++}`);
      values.push(Number(data.budget));
    }
    if (data.estimatedRemainingCost !== undefined || data.estimated_remaining_cost !== undefined) {
      fields.push(`estimated_remaining_cost = $${idx++}`);
      values.push(Number(data.estimatedRemainingCost ?? data.estimated_remaining_cost));
    }
    if (data.status !== undefined) {
      fields.push(`status = $${idx++}`);
      values.push(data.status);
    }
    if (data.categoryBudgets !== undefined || data.category_budgets !== undefined) {
      fields.push(`category_budgets = $${idx++}`);
      values.push(JSON.stringify(data.categoryBudgets ?? data.category_budgets));
    }

    if (fields.length === 0) {
      return this.findOne(id);
    }

    values.push(id);
    const sql = `UPDATE projects SET ${fields.join(', ')} WHERE id = $${idx} RETURNING *`;
    const res = await this.db.query(sql, values);
    if (!res.rows.length) {
      throw new NotFoundException(`Project not found: ${id}`);
    }

    return this.findOne(id);
  }

  async addRevenue(projectId: string, revenueData: any, createdById: string) {
    const res = await this.db.query(
      `INSERT INTO project_revenues (project_id, amount, date, note, created_by)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [
        projectId,
        Number(revenueData.amount),
        revenueData.date || new Date().toISOString().split('T')[0],
        revenueData.note || '',
        createdById,
      ],
    );

    return res.rows[0];
  }

  async closeProject(projectId: string, summary: any) {
    const res = await this.db.query(
      `UPDATE projects
       SET status = 'completed', is_closed = TRUE, closed_at = NOW(), closing_summary = $1
       WHERE id = $2
       RETURNING *`,
      [JSON.stringify(summary || {}), projectId],
    );

    if (!res.rows.length) {
      throw new NotFoundException(`Project not found: ${projectId}`);
    }

    return this.findOne(projectId);
  }
}
