import { Injectable, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { AuditLogsService } from '../audit-logs/audit-logs.service';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class ProjectsService {
  private parseSiteLocation(data: any, current?: { siteLatitude?: number | null; siteLongitude?: number | null }) {
    const latRaw = data.siteLatitude !== undefined ? data.siteLatitude : data.site_latitude;
    const lngRaw = data.siteLongitude !== undefined ? data.siteLongitude : data.site_longitude;
    const latGiven = data.siteLatitude !== undefined || data.site_latitude !== undefined;
    const lngGiven = data.siteLongitude !== undefined || data.site_longitude !== undefined;
    if (!latGiven && !lngGiven) return null;
    const lat = latGiven ? (latRaw === null ? null : Number(latRaw)) : current?.siteLatitude ?? null;
    const lng = lngGiven ? (lngRaw === null ? null : Number(lngRaw)) : current?.siteLongitude ?? null;
    if ((lat === null) !== (lng === null) ||
        (lat !== null && (!Number.isFinite(lat) || lat < -90 || lat > 90)) ||
        (lng !== null && (!Number.isFinite(lng) || lng < -180 || lng > 180))) {
      throw new BadRequestException('Provide a valid project site latitude and longitude together');
    }
    return { lat, lng };
  }

  constructor(
    private readonly db: DatabaseService,
    private readonly auditLogsService: AuditLogsService,
    private readonly notificationsService: NotificationsService,
  ) {}

  private mapProjectRow(p: any, revenues: any[] = [], members: any[] = [], detailedMembers: any[] = []) {
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
      incomeTaxRate: Number((p.category_budgets || {})._meta_income_tax_rate || 0),
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
      members: detailedMembers && detailedMembers.length > 0 ? detailedMembers : undefined,
      imageUrl: p.image_url || null,
      siteLatitude: p.site_latitude == null ? null : Number(p.site_latitude),
      siteLongitude: p.site_longitude == null ? null : Number(p.site_longitude),
      progressPercentage: Number(p.progress_percentage !== null && p.progress_percentage !== undefined ? p.progress_percentage : (p.category_budgets?._meta_progress ?? 0)),
      progress_percentage: Number(p.progress_percentage !== null && p.progress_percentage !== undefined ? p.progress_percentage : (p.category_budgets?._meta_progress ?? 0)),
      progressNotes: typeof p.progress_notes === 'string' ? JSON.parse(p.progress_notes) : (p.progress_notes || []),
      progress_notes: typeof p.progress_notes === 'string' ? JSON.parse(p.progress_notes) : (p.progress_notes || []),
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
        ) AS team_members,
        COALESCE(
          (SELECT json_agg(json_build_object(
            'userId', pm.user_id,
            'fullName', u.full_name,
            'email', u.email,
            'avatarUrl', u.avatar_url,
            'roleInProject', pm.role_in_project,
            'assignedAt', pm.assigned_at,
            'permissions', json_build_object(
              'canViewBudget', pm.can_view_budget,
              'canRecordRevenue', pm.can_record_revenue,
              'canViewExpenses', pm.can_view_expenses,
              'canCreateExpenses', pm.can_create_expenses,
              'canApproveExpenses', pm.can_approve_expenses,
              'canManageTasks', pm.can_manage_tasks,
              'canUpdateProgress', pm.can_update_progress,
              'canManageTeam', pm.can_manage_team,
              'canEditProject', pm.can_edit_project,
              'canViewAttendance', pm.can_view_attendance
            )
          ))
          FROM project_members pm
          LEFT JOIN users u ON u.id = pm.user_id
          WHERE pm.project_id = p.id),
          '[]'::json
        ) AS detailed_members
      FROM projects p
    `;

    const params: any[] = [];
    if (!isAdminOrFinance) {
      queryText += ` WHERE (p.created_by = $1 OR EXISTS (SELECT 1 FROM project_members pm WHERE pm.project_id = p.id AND pm.user_id = $1)) `;
      params.push(user.id);
    }

    queryText += ` ORDER BY p.created_at DESC `;

    const res = await this.db.query(queryText, params);
    return res.rows.map((row) => this.mapProjectRow(row, row.revenues, row.team_members, row.detailed_members));
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
        ) AS team_members,
        COALESCE(
          (SELECT json_agg(json_build_object(
            'userId', pm.user_id,
            'fullName', u.full_name,
            'email', u.email,
            'avatarUrl', u.avatar_url,
            'roleInProject', pm.role_in_project,
            'assignedAt', pm.assigned_at,
            'permissions', json_build_object(
              'canViewBudget', pm.can_view_budget,
              'canRecordRevenue', pm.can_record_revenue,
              'canViewExpenses', pm.can_view_expenses,
              'canCreateExpenses', pm.can_create_expenses,
              'canApproveExpenses', pm.can_approve_expenses,
              'canManageTasks', pm.can_manage_tasks,
              'canUpdateProgress', pm.can_update_progress,
              'canManageTeam', pm.can_manage_team,
              'canEditProject', pm.can_edit_project,
              'canViewAttendance', pm.can_view_attendance
            )
          ))
          FROM project_members pm
          LEFT JOIN users u ON u.id = pm.user_id
          WHERE pm.project_id = p.id),
          '[]'::json
        ) AS detailed_members
      FROM projects p
      WHERE p.id::text = $1 OR p.project_code = $1 OR LOWER(p.name) = LOWER($1)`,
      [id],
    );

    if (!res.rows.length) {
      throw new NotFoundException(`Project not found: ${id}`);
    }

    const row = res.rows[0];
    const project = this.mapProjectRow(row, row.revenues, row.team_members, row.detailed_members);

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
      const site = this.parseSiteLocation(data);
      const rawProgress = Number(data.progressPercentage ?? data.progress_percentage ?? data.categoryBudgets?._meta_progress ?? data.category_budgets?._meta_progress ?? 0);
      const initialProgress = Math.max(0, Math.min(100, isNaN(rawProgress) ? 0 : rawProgress));
      const initialNotes = data.progressNotes ?? data.progress_notes ?? [];

      const projRes = await client.query(
        `INSERT INTO projects (
          project_code, name, description, client_name, client_id, client_type, assignment_type,
          gross_project_value, tax_status, tax_rate, expected_net_revenue,
          advance_received, amount_received, amount_receivable, budget,
          category_budgets, estimated_remaining_cost, office_benefit_rate,
          start_date, end_date, status, created_by, image_url,
          progress_percentage, progress_notes, site_latitude, site_longitude
        ) VALUES (
          $1, $2, $3, $4, $5, $6, $7,
          $8, $9, $10, $11,
          $12, $13, $14, $15,
          $16, $17, $18,
          $19, $20, $21, $22, $23,
          $24, $25, $26, $27
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
          initialProgress,
          JSON.stringify(initialNotes),
          site?.lat ?? null,
          site?.lng ?? null,
        ],
      );

      const created = projRes.rows[0];

      // Support structured member assignments with custom role and permissions
      const memberList: Array<{ userId: string; roleInProject: string; permissions: any }> = [];
      const rawMemberList = data.members || data.teamMembers || data.team_members || [];
      if (Array.isArray(rawMemberList)) {
        for (const item of rawMemberList) {
          if (!item) continue;
          if (typeof item === 'string') {
            memberList.push({ userId: item, roleInProject: 'Member', permissions: {} });
          } else if (typeof item === 'object') {
            const uid = item.userId || item.user_id || item.id;
            if (uid) {
              memberList.push({
                userId: uid,
                roleInProject: (item.roleInProject || item.role_in_project || item.role || 'Member').trim(),
                permissions: item.permissions || item,
              });
            }
          }
        }
      }

      // Also include any bare teamMemberIds / team_member_ids if not already in memberList
      const rawIds: string[] = data.teamMemberIds || data.team_member_ids || [];
      for (const rawId of rawIds) {
        if (typeof rawId === 'string' && !memberList.some((m) => m.userId === rawId)) {
          memberList.push({ userId: rawId, roleInProject: 'Member', permissions: {} });
        }
      }

      // Ensure the project creator is always in memberList as Owner with full permissions if not specified
      if (validCreatedBy && uuidRegex.test(validCreatedBy)) {
        const creatorEntry = memberList.find((m) => m.userId === validCreatedBy);
        if (!creatorEntry) {
          memberList.unshift({
            userId: validCreatedBy,
            roleInProject: 'Owner',
            permissions: {
              canViewBudget: true,
              canRecordRevenue: true,
              canViewExpenses: true,
              canCreateExpenses: true,
              canApproveExpenses: true,
              canManageTasks: true,
              canUpdateProgress: true,
              canManageTeam: true,
              canEditProject: true,
              canViewAttendance: true,
            },
          });
        }
      }

      const insertedMembers: string[] = [];
      for (const m of memberList) {
        let memberId = m.userId;
        if (typeof memberId === 'string' && memberId.includes('@')) {
          const uRes = await client.query('SELECT id FROM users WHERE email = $1', [memberId.trim().toLowerCase()]);
          if (uRes.rows.length) {
            memberId = uRes.rows[0].id;
          }
        }
        if (uuidRegex.test(memberId)) {
          try {
            const perms = m.permissions || {};
            const isOwner = memberId === validCreatedBy;
            const roleInProject = m.roleInProject || (isOwner ? 'Owner' : 'Member');
            await client.query(
              `INSERT INTO project_members (
                project_id, user_id, role_in_project,
                can_view_budget, can_record_revenue, can_view_expenses, can_create_expenses,
                can_approve_expenses, can_manage_tasks, can_update_progress, can_manage_team,
                can_edit_project, can_view_attendance
              ) VALUES (
                $1, $2, $3,
                $4, $5, $6, $7,
                $8, $9, $10, $11,
                $12, $13
              )
              ON CONFLICT (project_id, user_id) DO UPDATE SET
                role_in_project = EXCLUDED.role_in_project,
                can_view_budget = EXCLUDED.can_view_budget,
                can_record_revenue = EXCLUDED.can_record_revenue,
                can_view_expenses = EXCLUDED.can_view_expenses,
                can_create_expenses = EXCLUDED.can_create_expenses,
                can_approve_expenses = EXCLUDED.can_approve_expenses,
                can_manage_tasks = EXCLUDED.can_manage_tasks,
                can_update_progress = EXCLUDED.can_update_progress,
                can_manage_team = EXCLUDED.can_manage_team,
                can_edit_project = EXCLUDED.can_edit_project,
                can_view_attendance = EXCLUDED.can_view_attendance`,
              [
                created.id,
                memberId,
                roleInProject,
                perms.canViewBudget ?? perms.can_view_budget ?? true,
                perms.canRecordRevenue ?? perms.can_record_revenue ?? isOwner,
                perms.canViewExpenses ?? perms.can_view_expenses ?? true,
                perms.canCreateExpenses ?? perms.can_create_expenses ?? true,
                perms.canApproveExpenses ?? perms.can_approve_expenses ?? isOwner,
                perms.canManageTasks ?? perms.can_manage_tasks ?? isOwner,
                perms.canUpdateProgress ?? perms.can_update_progress ?? isOwner,
                perms.canManageTeam ?? perms.can_manage_team ?? isOwner,
                perms.canEditProject ?? perms.can_edit_project ?? isOwner,
                perms.canViewAttendance ?? perms.can_view_attendance ?? true,
              ],
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
    const site = this.parseSiteLocation(data, existing);
    if (site) {
      fields.push(`site_latitude = $${idx++}`, `site_longitude = $${idx++}`);
      values.push(site.lat, site.lng);
    }

    if (data.name !== undefined) {
      fields.push(`name = $${idx++}`);
      values.push(data.name);
    }
    if (data.description !== undefined) {
      fields.push(`description = $${idx++}`);
      values.push(data.description);
    }
    const textFields: Array<[string, string[]]> = [
      ['client_name', ['client', 'client_name']],
      ['client_type', ['clientType', 'client_type']],
      ['assignment_type', ['assignmentType', 'assignment_type']],
      ['tax_status', ['taxStatus', 'tax_status']],
      ['status', ['status']],
    ];
    for (const [column, keys] of textFields) {
      const key = keys.find((candidate) => data[candidate] !== undefined);
      if (key) {
        fields.push(`${column} = $${idx++}`);
        values.push(data[key]);
      }
    }
    const monetaryFields: Array<[string, string[]]> = [
      ['gross_project_value', ['grossProjectValue', 'gross_project_value']],
      ['tax_rate', ['taxRate', 'tax_rate']],
      ['expected_net_revenue', ['expectedNetRevenue', 'expected_net_revenue']],
      ['advance_received', ['advanceReceived', 'advance_received']],
      ['amount_received', ['amountReceived', 'amount_received']],
      ['amount_receivable', ['amountReceivable', 'amount_receivable']],
      ['office_benefit_rate', ['officeBenefitRate', 'office_benefit_rate']],
    ];
    for (const [column, keys] of monetaryFields) {
      const key = keys.find((candidate) => data[candidate] !== undefined);
      if (key) {
        const value = Number(data[key]);
        fields.push(`${column} = $${idx++}`);
        values.push(Math.max(0, isNaN(value) ? 0 : value));
      }
    }
    const dateFields: Array<[string, string[]]> = [
      ['start_date', ['startDate', 'start_date']],
      ['end_date', ['endDate', 'end_date']],
    ];
    for (const [column, keys] of dateFields) {
      const key = keys.find((candidate) => data[candidate] !== undefined);
      if (key) {
        fields.push(`${column} = $${idx++}`);
        values.push(data[key]);
      }
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
    if (data.categoryBudgets !== undefined || data.category_budgets !== undefined) {
      const catBudgets = data.categoryBudgets ?? data.category_budgets;
      fields.push(`category_budgets = $${idx++}`);
      values.push(JSON.stringify(catBudgets));
      if (catBudgets && catBudgets._meta_progress !== undefined && data.progressPercentage === undefined && data.progress_percentage === undefined) {
        fields.push(`progress_percentage = $${idx++}`);
        const val = Number(catBudgets._meta_progress);
        values.push(Math.max(0, Math.min(100, isNaN(val) ? 0 : val)));
      }
    }
    if (data.progressPercentage !== undefined || data.progress_percentage !== undefined) {
      fields.push(`progress_percentage = $${idx++}`);
      const val = Number(data.progressPercentage ?? data.progress_percentage);
      values.push(Math.max(0, Math.min(100, isNaN(val) ? 0 : val)));
    }
    if (data.progressNotes !== undefined || data.progress_notes !== undefined) {
      fields.push(`progress_notes = $${idx++}`);
      values.push(JSON.stringify(data.progressNotes ?? data.progress_notes ?? []));
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

  async reopenProject(projectId: string) {
    const rawTarget = (projectId || '').trim();
    const res = await this.db.query(
      `UPDATE projects
       SET status = 'ongoing', is_closed = FALSE, closed_at = NULL, closing_summary = NULL
       WHERE id::text = $1 OR project_code = $1
       RETURNING *`,
      [rawTarget],
    );

    if (!res.rows.length) {
      throw new NotFoundException(`Project not found: ${projectId}`);
    }

    try {
      await this.auditLogsService.log({
        action: 'PROJECT_REOPENED',
        entityType: 'Project',
        entityId: res.rows[0].id,
        details: {},
      });
    } catch (_) {}

    return this.findOne(res.rows[0].id);
  }

  async delete(id: string, user?: any) {
    const rawTarget = (id || '').trim();
    if (!rawTarget) {
      return { success: false, message: 'Invalid project ID', deletedCount: 0 };
    }

    const res = await this.db.query(
      `DELETE FROM projects 
       WHERE id::text = $1 
          OR project_code = $1 
          OR LOWER(project_code) = LOWER($1) 
          OR LOWER(name) = LOWER($1)
       RETURNING id, project_code, name`,
      [rawTarget],
    );

    const deleted = res.rows;
    if (deleted.length > 0) {
      try {
        await this.auditLogsService.log(
          {
            action: 'PROJECT_DELETED',
            entityType: 'Project',
            entityId: deleted[0].id,
            details: { id: rawTarget, deleted },
          },
          user ? { id: user.id } : undefined,
        );
      } catch (_) {}
    }

    return { 
      success: true, 
      message: `Project ${id} deleted successfully`, 
      deletedCount: res.rowCount,
      deletedProjects: deleted 
    };
  }

  async getProjectMembers(projectId: string) {
    const rawTarget = (projectId || '').trim();
    const pRes = await this.db.query('SELECT id FROM projects WHERE id::text = $1 OR project_code = $1', [rawTarget]);
    if (!pRes.rows.length) {
      throw new NotFoundException(`Project not found: ${projectId}`);
    }
    const actualId = pRes.rows[0].id;

    const res = await this.db.query(`
      SELECT 
        pm.user_id as "userId",
        pm.project_id as "projectId",
        pm.role_in_project as "roleInProject",
        pm.assigned_at as "assignedAt",
        pm.can_view_budget as "canViewBudget",
        pm.can_record_revenue as "canRecordRevenue",
        pm.can_view_expenses as "canViewExpenses",
        pm.can_create_expenses as "canCreateExpenses",
        pm.can_approve_expenses as "canApproveExpenses",
        pm.can_manage_tasks as "canManageTasks",
        pm.can_update_progress as "canUpdateProgress",
        pm.can_manage_team as "canManageTeam",
        pm.can_edit_project as "canEditProject",
        pm.can_view_attendance as "canViewAttendance",
        u.full_name as "fullName",
        u.email,
        u.avatar_url as "avatarUrl",
        u.role as "systemRole",
        u.department,
        u.designation,
        u.phone
      FROM project_members pm
      JOIN users u ON u.id = pm.user_id
      WHERE pm.project_id = $1
      ORDER BY pm.assigned_at ASC
    `, [actualId]);

    return res.rows.map(r => ({
      userId: r.userId,
      projectId: r.projectId,
      fullName: r.fullName,
      email: r.email,
      avatarUrl: r.avatarUrl,
      systemRole: r.systemRole,
      department: r.department,
      designation: r.designation,
      phone: r.phone,
      roleInProject: r.roleInProject || 'Member',
      assignedAt: r.assignedAt,
      permissions: {
        canViewBudget: Boolean(r.canViewBudget),
        canRecordRevenue: Boolean(r.canRecordRevenue),
        canViewExpenses: Boolean(r.canViewExpenses),
        canCreateExpenses: Boolean(r.canCreateExpenses),
        canApproveExpenses: Boolean(r.canApproveExpenses),
        canManageTasks: Boolean(r.canManageTasks),
        canUpdateProgress: Boolean(r.canUpdateProgress),
        canManageTeam: Boolean(r.canManageTeam),
        canEditProject: Boolean(r.canEditProject),
        canViewAttendance: Boolean(r.canViewAttendance),
      }
    }));
  }

  async addOrUpdateProjectMember(projectId: string, dto: any, actorUser: any) {
    const rawTarget = (projectId || '').trim();
    const pRes = await this.db.query('SELECT id, name FROM projects WHERE id::text = $1 OR project_code = $1', [rawTarget]);
    if (!pRes.rows.length) {
      throw new NotFoundException(`Project not found: ${projectId}`);
    }
    const actualId = pRes.rows[0].id;
    const targetUserId = dto.userId || dto.user_id;
    if (!targetUserId) throw new BadRequestException('userId is required');

    const isGlobalAdmin = actorUser?.role === 'main_admin' || actorUser?.role === 'admin' || actorUser?.role === 'project_manager';
    if (!isGlobalAdmin) {
      const actorPm = await this.db.query(
        'SELECT can_manage_team FROM project_members WHERE project_id = $1 AND user_id = $2',
        [actualId, actorUser?.id]
      );
      if (!actorPm.rows.length || !actorPm.rows[0].can_manage_team) {
        throw new ForbiddenException('You do not have permission to manage members for this project');
      }
    }

    const perms = dto.permissions || {};
    const roleInProject = (dto.roleInProject || dto.role_in_project || dto.role || 'Member').trim();

    await this.db.query(`
      INSERT INTO project_members (
        project_id, user_id, role_in_project,
        can_view_budget, can_record_revenue, can_view_expenses, can_create_expenses,
        can_approve_expenses, can_manage_tasks, can_update_progress, can_manage_team,
        can_edit_project, can_view_attendance
      ) VALUES (
        $1, $2, $3,
        $4, $5, $6, $7,
        $8, $9, $10, $11,
        $12, $13
      )
      ON CONFLICT (project_id, user_id) DO UPDATE SET
        role_in_project = EXCLUDED.role_in_project,
        can_view_budget = EXCLUDED.can_view_budget,
        can_record_revenue = EXCLUDED.can_record_revenue,
        can_view_expenses = EXCLUDED.can_view_expenses,
        can_create_expenses = EXCLUDED.can_create_expenses,
        can_approve_expenses = EXCLUDED.can_approve_expenses,
        can_manage_tasks = EXCLUDED.can_manage_tasks,
        can_update_progress = EXCLUDED.can_update_progress,
        can_manage_team = EXCLUDED.can_manage_team,
        can_edit_project = EXCLUDED.can_edit_project,
        can_view_attendance = EXCLUDED.can_view_attendance
    `, [
      actualId,
      targetUserId,
      roleInProject,
      perms.canViewBudget ?? perms.can_view_budget ?? true,
      perms.canRecordRevenue ?? perms.can_record_revenue ?? false,
      perms.canViewExpenses ?? perms.can_view_expenses ?? true,
      perms.canCreateExpenses ?? perms.can_create_expenses ?? true,
      perms.canApproveExpenses ?? perms.can_approve_expenses ?? false,
      perms.canManageTasks ?? perms.can_manage_tasks ?? false,
      perms.canUpdateProgress ?? perms.can_update_progress ?? false,
      perms.canManageTeam ?? perms.can_manage_team ?? false,
      perms.canEditProject ?? perms.can_edit_project ?? false,
      perms.canViewAttendance ?? perms.can_view_attendance ?? true,
    ]);

    try {
      await this.notificationsService.create({
        userId: targetUserId,
        title: 'Project Role Updated',
        message: `You were assigned the role "${roleInProject}" on project ${pRes.rows[0].name}${perms.canApproveExpenses ? ' with expense claim approval authority' : ''}.`,
        type: 'project_assigned',
        relatedProjectId: actualId,
        actorId: actorUser?.id,
        actorName: actorUser?.fullName || actorUser?.name || 'Administrator',
      });
    } catch (_) {}

    return this.getProjectMembers(actualId);
  }

  async removeProjectMember(projectId: string, userId: string, actorUser: any) {
    const rawTarget = (projectId || '').trim();
    const pRes = await this.db.query('SELECT id FROM projects WHERE id::text = $1 OR project_code = $1', [rawTarget]);
    if (!pRes.rows.length) throw new NotFoundException(`Project not found: ${projectId}`);
    const actualId = pRes.rows[0].id;

    const isGlobalAdmin = actorUser?.role === 'main_admin' || actorUser?.role === 'admin' || actorUser?.role === 'project_manager';
    if (!isGlobalAdmin) {
      const actorPm = await this.db.query(
        'SELECT can_manage_team FROM project_members WHERE project_id = $1 AND user_id = $2',
        [actualId, actorUser?.id]
      );
      if (!actorPm.rows.length || !actorPm.rows[0].can_manage_team) {
        throw new ForbiddenException('You do not have permission to manage members for this project');
      }
    }

    await this.db.query('DELETE FROM project_members WHERE project_id = $1 AND user_id = $2', [actualId, userId]);
    return { success: true, userId, projectId: actualId };
  }

  async getMyProjectPermissions(projectId: string, user: any) {
    if (!user) throw new ForbiddenException();
    if (user.role === 'main_admin' || user.role === 'admin') {
      return {
        isSystemAdmin: true,
        roleInProject: 'System Administrator',
        permissions: {
          canViewBudget: true,
          canRecordRevenue: true,
          canViewExpenses: true,
          canCreateExpenses: true,
          canApproveExpenses: true,
          canManageTasks: true,
          canUpdateProgress: true,
          canManageTeam: true,
          canEditProject: true,
          canViewAttendance: true,
        }
      };
    }

    const rawTarget = (projectId || '').trim();
    const pRes = await this.db.query('SELECT id, created_by FROM projects WHERE id::text = $1 OR project_code = $1', [rawTarget]);
    if (!pRes.rows.length) throw new NotFoundException(`Project not found: ${projectId}`);
    const actualId = pRes.rows[0].id;

    if (pRes.rows[0].created_by === user.id) {
      return {
        isSystemAdmin: false,
        isCreator: true,
        roleInProject: 'Project Creator',
        permissions: {
          canViewBudget: true,
          canRecordRevenue: true,
          canViewExpenses: true,
          canCreateExpenses: true,
          canApproveExpenses: true,
          canManageTasks: true,
          canUpdateProgress: true,
          canManageTeam: true,
          canEditProject: true,
          canViewAttendance: true,
        }
      };
    }

    const pm = await this.db.query('SELECT * FROM project_members WHERE project_id = $1 AND user_id = $2', [actualId, user.id]);
    if (!pm.rows.length) {
      return {
        isSystemAdmin: false,
        isMember: false,
        roleInProject: 'Non-Member',
        permissions: {
          canViewBudget: false,
          canRecordRevenue: false,
          canViewExpenses: false,
          canCreateExpenses: false,
          canApproveExpenses: false,
          canManageTasks: false,
          canUpdateProgress: false,
          canManageTeam: false,
          canEditProject: false,
          canViewAttendance: false,
        }
      };
    }

    const r = pm.rows[0];
    return {
      isSystemAdmin: false,
      isMember: true,
      roleInProject: r.role_in_project || 'Member',
      permissions: {
        canViewBudget: Boolean(r.can_view_budget),
        canRecordRevenue: Boolean(r.can_record_revenue),
        canViewExpenses: Boolean(r.can_view_expenses),
        canCreateExpenses: Boolean(r.can_create_expenses),
        canApproveExpenses: Boolean(r.can_approve_expenses),
        canManageTasks: Boolean(r.can_manage_tasks),
        canUpdateProgress: Boolean(r.can_update_progress),
        canManageTeam: Boolean(r.can_manage_team),
        canEditProject: Boolean(r.can_edit_project),
        canViewAttendance: Boolean(r.can_view_attendance),
      }
    };
  }
}


