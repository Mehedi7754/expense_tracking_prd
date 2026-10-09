import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { AuditLogsService } from '../audit-logs/audit-logs.service';

@Injectable()
export class ProjectsService {
  constructor(
    private readonly db: DatabaseService,
    private readonly auditLogsService: AuditLogsService,
  ) {}

  private mapProjectRow(p: any, revenues: any[] = [], members: any[] = []) {
    const memberIds = (members || []).map((m) => m.user_id || m);
    if (p.created_by && !memberIds.includes(p.created_by)) {
      memberIds.push(p.created_by);
    }

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
      createdById: p.created_by,
      teamMemberIds: memberIds,
      imageUrl: p.image_url || null,
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
    const isAdminOrFinance =
      user.role === 'main_admin' ||
      user.role === 'finance' ||
      user.role === 'finance_manager';
    
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
      queryText += ` WHERE (p.created_by = $1 OR EXISTS (SELECT 1 FROM project_members pm WHERE pm.project_id = p.id AND pm.user_id = $1)) `;
      params.push(user.id);
    }

    queryText += ` ORDER BY p.created_at DESC `;

    const res = await this.db.query(queryText, params);
    return res.rows.map((row) => this.mapProjectRow(row, row.revenues, row.team_members));
  }

  async findOne(id: string, user?: any) {
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
      WHERE p.id::text = $1 OR p.project_code = $1 OR LOWER(p.name) = LOWER($1)`,
      [id],
    );

    if (!res.rows.length) {
      throw new NotFoundException(`Project not found: ${id}`);
    }

    const row = res.rows[0];
    const project = this.mapProjectRow(row, row.revenues, row.team_members);

    if (user && user.role !== 'main_admin' && user.role !== 'finance_manager' && user.role !== 'finance') {
      const isCreator = row.created_by === user.id;
      const isMember = (project.teamMemberIds || []).includes(user.id) || (user.assignedProjectIds || []).includes(project.id);
      if (!isCreator && !isMember) {
        throw new ForbiddenException('You do not have permission to view this project');
      }
    }

    return project;
  }

  async create(data: any, createdById: string) {
    return this.db.transaction(async (client) => {
      const rawGross = Number(data.grossProjectValue || data.gross_project_value || 0);
      const gross = Math.max(0, isNaN(rawGross) ? 0 : rawGross);
      const rawTaxRate = Number(data.taxRate || data.tax_rate || 0.1);
      const taxRate = Math.max(0, Math.min(1, isNaN(rawTaxRate) ? 0.1 : rawTaxRate));

      // Normalize assignment_type to snake_case enum
      const rawAssignment = (data.assignment_type || data.assignmentType || 'direct_consultancy').toString();
      let assignmentType = 'direct_consultancy';
      const cleanAssignment = rawAssignment.toLowerCase().replace(/[\s\-_]/g, '');
      if (cleanAssignment.includes('subconsultancy')) {
        assignmentType = 'sub_consultancy';
      } else if (cleanAssignment.includes('government')) {
        assignmentType = 'government';
      } else if (cleanAssignment.includes('private')) {
        assignmentType = 'private';
      } else {
        assignmentType = 'direct_consultancy';
      }

      // Normalize tax_status to snake_case enum
      const rawTax = (data.tax_status || data.taxStatus || 'included').toString();
      let taxStatus = 'included';
      const cleanTax = rawTax.toLowerCase().replace(/[\s\-_]/g, '');
      if (cleanTax.includes('excluded')) {
        taxStatus = 'excluded';
      } else if (cleanTax.includes('notapplicable') || cleanTax === 'na') {
        taxStatus = 'not_applicable';
      } else {
        taxStatus = 'included';
      }

      const netRevenue = Math.max(0, taxStatus === 'included' ? gross * (1 - taxRate) : gross);
      const rawBudget = Number(data.budget || gross * 0.85);
      const budget = Math.max(0, isNaN(rawBudget) ? 0 : rawBudget);
      const rawAdvance = Number(data.advanceReceived || data.advance_received || 0);
      const advanceReceived = Math.max(0, isNaN(rawAdvance) ? 0 : rawAdvance);
      const rawReceived = Number(data.amountReceived || data.amount_received || 0);
      const amountReceived = Math.max(0, isNaN(rawReceived) ? 0 : rawReceived);
      const receivable = Math.max(0, gross - amountReceived);

      // Project code auto-generation if not supplied
      let projectCode = data.projectId || data.project_code;
      if (!projectCode) {
        const countRes = await client.query('SELECT count(*) FROM projects');
        const num = parseInt(countRes.rows[0].count, 10) + 1;
        const rand = Math.floor(100 + Math.random() * 900);
        projectCode = `PRJ-${new Date().getFullYear()}-${num.toString().padStart(3, '0')}-${rand}`;
      }

      const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
      const validCreatedBy = (createdById && uuidRegex.test(createdById)) ? createdById : null;

      let clientId = data.clientId || data.client_id || null;
      if (clientId && !uuidRegex.test(clientId)) {
        clientId = null;
      }

      const imageUrl = data.imageUrl || data.image_url || null;

      const projRes = await client.query(
        `INSERT INTO projects (
          project_code, name, description, client_name, client_id, client_type, assignment_type,
          gross_project_value, tax_status, tax_rate, expected_net_revenue,
          advance_received, amount_received, amount_receivable, budget,
          category_budgets, estimated_remaining_cost, office_benefit_rate,
          start_date, end_date, status, created_by, image_url
        ) VALUES (
          $1, $2, $3, $4, $5, $6, $7,
          $8, $9, $10, $11,
          $12, $13, $14, $15,
          $16, $17, $18,
          $19, $20, $21, $22, $23
        ) RETURNING *`,
        [
          projectCode,
          data.name,
          data.description || '',
          data.client || data.client_name || 'Client',
          clientId,
          data.clientType || data.client_type || 'private',
          assignmentType,
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
          validCreatedBy,
          imageUrl,
        ],
      );

      const created = projRes.rows[0];

      // Insert team members safely
      const rawMembers: string[] = data.teamMemberIds || data.team_member_ids || [];
      const teamMembers = [...rawMembers];
      // Ensure the project creator is always added as a project member
      if (validCreatedBy && uuidRegex.test(validCreatedBy) && !teamMembers.includes(validCreatedBy)) {
        teamMembers.unshift(validCreatedBy);
      }

      const insertedMembers: string[] = [];
      for (const rawMember of teamMembers) {
        let memberId = rawMember;
        if (typeof memberId === 'string' && memberId.includes('@')) {
          const uRes = await client.query('SELECT id FROM users WHERE email = $1', [memberId.trim().toLowerCase()]);
          if (uRes.rows.length) {
            memberId = uRes.rows[0].id;
          }
        }
        if (uuidRegex.test(memberId)) {
          try {
            await client.query(
              `INSERT INTO project_members (project_id, user_id, role_in_project)
               VALUES ($1, $2, $3)
               ON CONFLICT DO NOTHING`,
              [created.id, memberId, memberId === validCreatedBy ? 'Owner' : 'Member'],
            );
            insertedMembers.push(memberId);
          } catch (_) {
            // Ignore non-existent user FK failures
          }
        }
      }

      const mapped = this.mapProjectRow(created, [], insertedMembers);
      try {
        await this.auditLogsService.log(
          {
            action: 'PROJECT_CREATED',
            entityType: 'Project',
            entityId: created.id,
            details: { name: created.name, code: created.project_code, gross: created.gross_project_value },
          },
          { id: validCreatedBy },
        );
      } catch (_) {}

      return mapped;
    });
  }

  async update(id: string, data: any, user?: any) {
    const existing = await this.findOne(id, user);

    const isAdminOrFinance = user?.role === 'main_admin' || user?.role === 'finance_manager' || user?.role === 'finance';
    if (user && !isAdminOrFinance) {
      const isAssigned = (existing.teamMemberIds || []).includes(user.id) || (user.assignedProjectIds || []).includes(existing.id);
      if (!isAssigned) {
        throw new ForbiddenException('You do not have permission to update this project');
      }
    }

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
      const val = Number(data.budget);
      values.push(Math.max(0, isNaN(val) ? 0 : val));
    }
    if (data.estimatedRemainingCost !== undefined || data.estimated_remaining_cost !== undefined) {
      fields.push(`estimated_remaining_cost = $${idx++}`);
      const val = Number(data.estimatedRemainingCost ?? data.estimated_remaining_cost);
      values.push(Math.max(0, isNaN(val) ? 0 : val));
    }
    if (data.status !== undefined) {
      fields.push(`status = $${idx++}`);
      values.push(data.status);
    }
    if (data.categoryBudgets !== undefined || data.category_budgets !== undefined) {
      fields.push(`category_budgets = $${idx++}`);
      values.push(JSON.stringify(data.categoryBudgets ?? data.category_budgets));
    }
    if (data.imageUrl !== undefined || data.image_url !== undefined) {
      fields.push(`image_url = $${idx++}`);
      values.push(data.imageUrl ?? data.image_url);
    }

    if (data.teamMemberIds !== undefined || data.team_member_ids !== undefined) {
      const rawMembers: string[] = data.teamMemberIds || data.team_member_ids || [];
      const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
      for (const rawMember of rawMembers) {
        let memberId = rawMember;
        if (typeof memberId === 'string' && memberId.includes('@')) {
          const uRes = await this.db.query('SELECT id FROM users WHERE email = $1', [memberId.trim().toLowerCase()]);
          if (uRes.rows.length) {
            memberId = uRes.rows[0].id;
          }
        }
        if (uuidRegex.test(memberId)) {
          try {
            await this.db.query(
              `INSERT INTO project_members (project_id, user_id, role_in_project)
               VALUES ($1, $2, 'Member')
               ON CONFLICT DO NOTHING`,
              [id, memberId],
            );
          } catch (_) {}
        }
      }
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

    const updated = await this.findOne(id);
    try {
      await this.auditLogsService.log({
        action: 'PROJECT_UPDATED',
        entityType: 'Project',
        entityId: id,
        details: data,
      });
    } catch (_) {}

    return updated;
  }

  async addRevenue(projectId: string, revenueData: any, createdById: string) {
    const amount = Number(revenueData.amount || 0);
    return this.db.transaction(async (client) => {
      const res = await client.query(
        `INSERT INTO project_revenues (project_id, amount, date, note, created_by)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING *`,
        [
          projectId,
          amount,
          revenueData.date || new Date().toISOString().split('T')[0],
          revenueData.note || '',
          createdById,
        ],
      );

      // Recalculate amount_received and amount_receivable on the project
      await client.query(
        `UPDATE projects
         SET amount_received = amount_received + $1,
             amount_receivable = GREATEST(0, gross_project_value - (amount_received + $1))
         WHERE id = $2`,
        [amount, projectId],
      );

      try {
        await this.auditLogsService.log(
          {
            action: 'PROJECT_REVENUE_ADDED',
            entityType: 'Project',
            entityId: projectId,
            details: { amount, note: revenueData.note },
          },
          { id: createdById },
        );
      } catch (_) {}

      return res.rows[0];
    });
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

    try {
      await this.auditLogsService.log({
        action: 'PROJECT_CLOSED',
        entityType: 'Project',
        entityId: projectId,
        details: summary || {},
      });
    } catch (_) {}

    return this.findOne(projectId);
  }

  async delete(id: string, user?: any) {
    const rawTarget = (id || '').trim();
    if (!rawTarget) {
      return { success: false, message: 'Invalid project ID', deletedCount: 0 };
    }

    // Resolve all matching project IDs, project codes, and names
    const findRes = await this.db.query(
      `SELECT id::text AS id, project_code, name FROM projects 
       WHERE id::text = $1 
          OR project_code = $1 
          OR LOWER(project_code) = LOWER($1) 
          OR LOWER(name) = LOWER($1)`,
      [rawTarget],
    );

    const idsToDelete = new Set<string>([rawTarget]);
    const codesToDelete = new Set<string>([rawTarget]);
    const namesToDelete = new Set<string>([rawTarget]);

    for (const row of findRes.rows) {
      if (row.id) idsToDelete.add(row.id.toString());
      if (row.project_code) codesToDelete.add(row.project_code.toString());
      if (row.name) namesToDelete.add(row.name.toString());
    }

    return this.db.transaction(async (client) => {
      const idList = Array.from(idsToDelete);
      const codeList = Array.from(codesToDelete);
      const nameList = Array.from(namesToDelete);
      // 0. Clean up chat messages and project chat channels
      await client.query(
        'UPDATE chat_messages SET project_id = NULL WHERE project_id::text = ANY($1::text[]) OR project_id::text = ANY($2::text[])',
        [idList, codeList],
      ).catch(() => {});
      await client.query(
        'DELETE FROM chat_channels WHERE project_id::text = ANY($1::text[]) OR project_id::text = ANY($2::text[])',
        [idList, codeList],
      ).catch(() => {});

      // 1. Delete comments on expenses belonging to this project
      await client.query(
        `DELETE FROM expense_comments
         WHERE expense_id IN (
           SELECT id FROM expenses WHERE project_id::text = ANY($1::text[]) OR project_id::text = ANY($2::text[])
         )`,
        [idList, codeList],
      );

      // 2. Delete notifications referencing expenses or this project
      await client.query(
        `DELETE FROM notifications
         WHERE related_project_id::text = ANY($1::text[]) OR related_project_id::text = ANY($2::text[])
            OR related_expense_id IN (
              SELECT id FROM expenses WHERE project_id::text = ANY($1::text[]) OR project_id::text = ANY($2::text[])
            )`,
        [idList, codeList],
      );

      // 3. Delete expenses belonging to this project
      await client.query(
        'DELETE FROM expenses WHERE project_id::text = ANY($1::text[]) OR project_id::text = ANY($2::text[])',
        [idList, codeList],
      );

      // 4. Delete tasks belonging to this project
      await client.query(
        'DELETE FROM tasks WHERE project_id::text = ANY($1::text[]) OR project_id::text = ANY($2::text[])',
        [idList, codeList],
      );

      // 5. Delete project revenues
      await client.query(
        'DELETE FROM project_revenues WHERE project_id::text = ANY($1::text[]) OR project_id::text = ANY($2::text[])',
        [idList, codeList],
      );

      // 6. Delete project members
      await client.query(
        'DELETE FROM project_members WHERE project_id::text = ANY($1::text[]) OR project_id::text = ANY($2::text[])',
        [idList, codeList],
      );

      // 7. Delete project record
      const res = await client.query(
        `DELETE FROM projects 
         WHERE id::text = ANY($1::text[]) 
            OR project_code = ANY($2::text[]) 
            OR LOWER(name) = ANY(SELECT LOWER(x) FROM unnest($3::text[]) x) 
         RETURNING *`,
        [idList, codeList, nameList],
      );

      try {
        await this.auditLogsService.log(
          {
            action: 'PROJECT_DELETED',
            entityType: 'Project',
            entityId: idList[0],
            details: { id, idList, codeList, nameList },
          },
          user ? { id: user.id } : undefined,
        );
      } catch (_) {}

      return { success: true, message: `Project ${id} deleted successfully`, deletedCount: res.rowCount };
    });
  }
}

