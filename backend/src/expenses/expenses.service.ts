import { Injectable, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { AuditLogsService } from '../audit-logs/audit-logs.service';
import { NotificationsService } from '../notifications/notifications.service';
import { EmailService } from '../email/email.service';

@Injectable()
export class ExpensesService {
  constructor(
    private readonly db: DatabaseService,
    private readonly auditLogsService: AuditLogsService,
    private readonly notificationsService: NotificationsService,
    private readonly emailService: EmailService,
  ) {}

  private mapExpenseRow(e: any, comments: any[] = []) {
    const details = typeof e.category_details === 'string' ? JSON.parse(e.category_details) : e.category_details || {};

    return {
      id: e.id,
      employeeId: e.employee_id,
      employeeName: e.employee_name || 'Team Member',
      employeeAvatar: e.employee_avatar || null,
      employee_avatar: e.employee_avatar || null,
      projectId: e.project_id,
      projectName: e.project_name || 'Project',
      taskId: e.task_id,
      amount: Number(e.amount),
      baseCost: Number(e.base_amount || e.amount),
      base_cost: Number(e.base_amount || e.amount),
      vatRate: Number(e.vat_rate || 0),
      vat_rate: Number(e.vat_rate || 0),
      vatAmount: Number(e.vat_amount || 0),
      vat_amount: Number(e.vat_amount || 0),
      taxRate: Number(e.tax_rate || 0),
      tax_rate: Number(e.tax_rate || 0),
      taxAmount: Number(e.tax_amount || 0),
      tax_amount: Number(e.tax_amount || 0),
      officeBenefitAmount: Number(e.office_benefit_amount),
      currency: e.currency,
      categoryId: e.category_id,
      categoryName: e.category_name || 'Category',
      categoryIcon: e.category_icon || 'expense',
      note: e.note || '',
      date: e.date,
      hasReceipt: Boolean(e.has_receipt),
      receiptPhotoUrl: e.receipt_photo_url || (Array.isArray(e.receipt_photo_urls) && e.receipt_photo_urls[0]) || null,
      receiptPhotoUrls: Array.isArray(e.receipt_photo_urls) && e.receipt_photo_urls.length > 0
        ? e.receipt_photo_urls
        : (e.receipt_photo_url ? [e.receipt_photo_url] : []),
      receiptPhotos: e.receipt_photos && Array.isArray(e.receipt_photos) ? e.receipt_photos : [],
      status: e.status,
      rejectionReason: e.rejection_reason,
      justificationStatus: e.justification_status,
      justificationReason: e.justification_reason,
      justificationComment: e.justification_comment,
      justificationAttachmentUrl: e.justification_attachment_url,
      justificationReviewedBy: e.justification_reviewed_by,
      justificationReviewComment: e.justification_review_comment,
      justificationReviewedAt: e.justification_reviewed_at,
      createdAt: e.created_at,
      updatedAt: e.updated_at,
      equipmentDetails: details.equipment_name ? {
        equipmentName: details.equipment_name,
        serialNumber: details.serial_number,
        condition: details.condition,
        modelNumber: details.model_number,
      } : null,
      transportationDetails: details.transportation_type ? {
        transportationType: details.transportation_type,
        fromLocation: details.from_location,
        toLocation: details.to_location,
        vehicleType: details.vehicle_type,
      } : null,
      foodDetails: details.meal_type ? {
        mealType: details.meal_type,
        numberOfPeople: Number(details.number_of_people || 1),
        costPerPerson: Number(details.cost_per_person || 0),
        restaurantName: details.restaurant_name,
      } : null,
      accommodationDetails: details.hotel_name ? {
        hotelName: details.hotel_name,
        checkInDate: details.check_in_date,
        checkOutDate: details.check_out_date,
        roomType: details.room_type,
      } : null,
      officeCostDetails: details.sub_category ? {
        subCategory: details.sub_category,
        justification: details.justification,
        vendor: details.vendor,
      } : null,
      comments: (comments || []).map((c) => ({
        id: c.id,
        expenseId: c.expense_id || c.expenseId,
        authorId: c.author_id || c.authorId,
        authorName: c.author_name || c.authorName || c.userName || c.full_name || 'Team Member',
        userName: c.author_name || c.authorName || c.userName || c.full_name || 'Team Member',
        user_name: c.author_name || c.authorName || c.userName || c.full_name || 'Team Member',
        authorRole: c.author_role || c.authorRole || 'Member',
        authorAvatar: c.author_avatar || c.authorAvatar || c.avatar_url || c.avatarUrl || null,
        avatarUrl: c.author_avatar || c.authorAvatar || c.avatar_url || c.avatarUrl || null,
        comment: c.comment_text || c.comment || c.text || '',
        text: c.comment_text || c.comment || c.text || '',
        createdAt: c.created_at || c.createdAt,
      })),
    };
  }

  async findAll(query: { projectId?: string; employeeId?: string; status?: string }, user: any) {
    let sql = `
      SELECT e.*,
        u.full_name AS employee_name,
        u.avatar_url AS employee_avatar,
        p.name AS project_name,
        p.image_url AS project_image_url,
        c.name AS category_name,
        c.icon_name AS category_icon,
        COALESCE(
          (SELECT json_agg(json_build_object(
            'id', ec.id, 'expense_id', ec.expense_id, 'author_id', ec.author_id,
            'author_name', COALESCE(u_c.full_name, ec.author_name),
            'author_role', COALESCE(u_c.role, ec.author_role),
            'author_avatar', u_c.avatar_url,
            'comment_text', ec.comment_text,
            'created_at', ec.created_at
          ) ORDER BY ec.created_at ASC)
          FROM expense_comments ec
          LEFT JOIN users u_c ON u_c.id = ec.author_id
          WHERE ec.expense_id = e.id),
          '[]'::json
        ) AS comments
      FROM expenses e
      JOIN users u ON u.id = e.employee_id
      JOIN projects p ON p.id = e.project_id
      JOIN categories c ON c.id = e.category_id
      WHERE 1=1
    `;

    const params: any[] = [];
    let idx = 1;

    // Access control: regular member sees their own expenses OR expenses for projects where they have can_approve_expenses or can_view_expenses
    const isGlobalAdminOrFinance = ['main_admin', 'admin', 'finance', 'finance_manager'].includes(user.role);
    if (!isGlobalAdminOrFinance) {
      if (user.role === 'project_manager') {
        sql += ` AND EXISTS (SELECT 1 FROM project_members pm WHERE pm.project_id = e.project_id AND pm.user_id = $${idx++})`;
        params.push(user.id);
      } else {
        sql += ` AND (
          e.employee_id = $${idx} 
          OR EXISTS (
            SELECT 1 FROM project_members pm 
            WHERE pm.project_id = e.project_id 
              AND pm.user_id = $${idx} 
              AND (pm.can_approve_expenses = TRUE OR pm.can_view_expenses = TRUE OR pm.role_in_project ILIKE '%Manager%' OR pm.role_in_project ILIKE '%Lead%')
          )
        )`;
        params.push(user.id);
        idx++;
      }
    }

    if (query.projectId) {
      sql += ` AND (e.project_id::text = $${idx} OR p.project_code = $${idx} OR p.id::text = $${idx})`;
      params.push(query.projectId);
      idx++;
    }
    if (query.employeeId) {
      sql += ` AND e.employee_id = $${idx++}`;
      params.push(query.employeeId);
    }
    if (query.status) {
      sql += ` AND e.status = $${idx++}`;
      params.push(query.status);
    }

    sql += ` ORDER BY e.created_at DESC`;

    const res = await this.db.query(sql, params);
    return res.rows.map((r) => this.mapExpenseRow(r, r.comments));
  }

  async findOne(id: string, user?: any) {
    const sql = `
      SELECT e.*,
        u.full_name AS employee_name,
        u.avatar_url AS employee_avatar,
        p.name AS project_name,
        p.image_url AS project_image_url,
        c.name AS category_name,
        c.icon_name AS category_icon,
        COALESCE(
          (SELECT json_agg(json_build_object(
            'id', ec.id, 'expense_id', ec.expense_id, 'author_id', ec.author_id,
            'author_name', COALESCE(u_c.full_name, ec.author_name),
            'author_role', COALESCE(u_c.role, ec.author_role),
            'author_avatar', u_c.avatar_url,
            'comment_text', ec.comment_text,
            'created_at', ec.created_at
          ) ORDER BY ec.created_at ASC)
          FROM expense_comments ec
          LEFT JOIN users u_c ON u_c.id = ec.author_id
          WHERE ec.expense_id = e.id),
          '[]'::json
        ) AS comments
      FROM expenses e
      JOIN users u ON u.id = e.employee_id
      JOIN projects p ON p.id = e.project_id
      JOIN categories c ON c.id = e.category_id
      WHERE e.id = $1
    `;

    const res = await this.db.query(sql, [id]);
    if (!res.rows.length) {
      throw new NotFoundException(`Expense not found: ${id}`);
    }

    const expense = this.mapExpenseRow(res.rows[0], res.rows[0].comments);

    if (user && user.role !== 'main_admin' && user.role !== 'admin' && user.role !== 'finance_manager' && user.role !== 'finance') {
      const isOwner = expense.employeeId === user.id;
      if (!isOwner) {
        const pmCheck = await this.db.query(
          'SELECT can_view_expenses, can_approve_expenses FROM project_members WHERE project_id = $1 AND user_id = $2',
          [expense.projectId, user.id],
        );
        if (!pmCheck.rows.length) {
          throw new ForbiddenException('You do not have permission to view this expense report');
        }
      }
    }

    return expense;
  }

  async create(data: any, user: any) {
    const isAdmin = user?.role === 'main_admin';
    const employeeId = (isAdmin && (data.employeeId || data.employee_id)) ? (data.employeeId || data.employee_id) : user.id;
    const initialStatus = (isAdmin && data.status) ? data.status : 'pending';

    const rawProjectId = data.projectId || data.project_id;
    if (!rawProjectId) {
      throw new BadRequestException('Project ID is required');
    }

    const projRes = await this.db.query(
      `SELECT id, name, is_closed, status FROM projects WHERE id::text = $1 OR project_code = $1 LIMIT 1`,
      [rawProjectId],
    );
    if (!projRes.rows.length) {
      throw new NotFoundException(`Project not found: ${rawProjectId}`);
    }
    const project = projRes.rows[0];
    if (project.is_closed === true || (project.status && ['closed', 'completed'].includes(project.status.toLowerCase()))) {
      throw new BadRequestException('Cannot submit expenses for a closed project');
    }
    const validProjectId = project.id;

    if (!isAdmin && user?.role !== 'finance_manager' && user?.role !== 'finance') {
      const memberCheck = await this.db.query(
        'SELECT can_create_expenses FROM project_members WHERE project_id = $1 AND user_id = $2',
        [validProjectId, user.id],
      );
      if (!memberCheck.rows.length) {
        throw new ForbiddenException('You are not assigned to this project');
      }
      if (memberCheck.rows[0].can_create_expenses === false) {
        throw new ForbiddenException('You do not have permission to submit expenses for this project');
      }
    }

    let categoryId = data.categoryId || data.category_id;
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!categoryId || !uuidRegex.test(categoryId)) {
      const cleanSlug = (categoryId || '').toString().replace(/^cat_/, '');
      const rawName = data.categoryName || data.category_name ||
        (categoryId ? categoryId.toString().replace(/^cat_/, '') : 'General');
      const formatted = rawName.charAt(0).toUpperCase() + rawName.slice(1);

      let mappedName = rawName;
      const lowerSlug = cleanSlug.toLowerCase();
      if (lowerSlug.includes('meal') || lowerSlug.includes('food') || lowerSlug.includes('dining')) mappedName = 'Food';
      else if (lowerSlug.includes('lodg') || lowerSlug.includes('hotel') || lowerSlug.includes('accommodat')) mappedName = 'Accommodation';
      else if (lowerSlug.includes('hard') || lowerSlug.includes('equip') || lowerSlug.includes('device')) mappedName = 'Equipment';
      else if (lowerSlug.includes('transp') || lowerSlug.includes('taxi')) mappedName = 'Transportation';
      else if (lowerSlug.includes('soft') || lowerSlug.includes('tool')) mappedName = 'Software & Tools';
      else if (lowerSlug.includes('office') || lowerSlug.includes('suppl')) mappedName = 'Office Cost';
      else if (lowerSlug.includes('travel') || lowerSlug.includes('flight')) mappedName = 'Travel & Flights';

      const catRes = await this.db.query(
        'SELECT id FROM categories WHERE name ILIKE $1 OR name ILIKE $2 OR LOWER(name) = LOWER($3) OR LOWER(name) = LOWER($4) LIMIT 1',
        [`%${categoryId || ''}%`, `%${cleanSlug}%`, rawName, mappedName],
      );
      if (catRes.rows.length) {
        categoryId = catRes.rows[0].id;
      } else {
        const newCat = await this.db.query(
          'INSERT INTO categories (name, icon_name, is_default) VALUES ($1, $2, TRUE) RETURNING id',
          [formatted, data.categoryIcon || 'category'],
        );
        categoryId = newCat.rows[0]?.id;
      }
    }

    const categoryDetails = data.categoryDetails || data.category_details || {};
    if (data.equipmentDetails) Object.assign(categoryDetails, { equipment_name: data.equipmentDetails.equipmentName, serial_number: data.equipmentDetails.serialNumber });
    if (data.transportationDetails) Object.assign(categoryDetails, { transportation_type: data.transportationDetails.transportationType, from_location: data.transportationDetails.fromLocation, to_location: data.transportationDetails.toLocation });
    if (data.foodDetails) Object.assign(categoryDetails, { meal_type: data.foodDetails.mealType, number_of_people: data.foodDetails.numberOfPeople, cost_per_person: data.foodDetails.costPerPerson });
    if (data.accommodationDetails) Object.assign(categoryDetails, { hotel_name: data.accommodationDetails.hotelName, check_in_date: data.accommodationDetails.checkInDate, check_out_date: data.accommodationDetails.checkOutDate });
    if (data.officeCostDetails) Object.assign(categoryDetails, { sub_category: data.officeCostDetails.subCategory, justification: data.officeCostDetails.justification });

    const hasReceipt = data.hasReceipt ?? data.has_receipt ?? true;
    const justificationStatus = hasReceipt ? 'none' : (data.justificationStatus || 'submitted');

    const baseAmount = Number(data.baseAmount ?? data.base_amount ?? data.baseCost ?? data.base_cost ?? data.amount);
    const vatRate = Number(data.vatRate ?? data.vat_rate ?? 0);
    const vatAmount = Number(data.vatAmount ?? data.vat_amount ?? (vatRate > 0 ? (baseAmount * vatRate / 100) : 0));
    const taxRate = Number(data.taxRate ?? data.tax_rate ?? 0);
    const taxAmount = Number(data.taxAmount ?? data.tax_amount ?? (taxRate > 0 ? (baseAmount * taxRate / 100) : 0));

    const receiptUrls: string[] = Array.isArray(data.receiptPhotoUrls)
      ? data.receiptPhotoUrls
      : (Array.isArray(data.receipt_photo_urls)
        ? data.receipt_photo_urls
        : (data.receiptPhotoUrl || data.receipt_photo_url ? [data.receiptPhotoUrl || data.receipt_photo_url] : []));
    const primaryReceiptUrl = receiptUrls[0] || data.receiptPhotoUrl || data.receipt_photo_url || null;
    const receiptPhotos = Array.isArray(data.receiptPhotos) ? data.receiptPhotos : (Array.isArray(data.receipt_photos) ? data.receipt_photos : []);

    const res = await this.db.query(
      `INSERT INTO expenses (
        employee_id, project_id, task_id, amount, currency, category_id,
        note, date, has_receipt, receipt_photo_url, status,
        justification_status, justification_reason, justification_comment,
        category_details, base_amount, vat_rate, vat_amount, tax_rate, tax_amount,
        receipt_photo_urls, receipt_photos
      ) VALUES (
        $1, $2, $3, $4, $5, $6,
        $7, $8, $9, $10, $11,
        $12, $13, $14,
        $15, $16, $17, $18, $19, $20,
        $21, $22
      ) RETURNING id`,
      [
        employeeId,
        validProjectId,
        data.taskId || data.task_id || null,
        Number(data.amount),
        data.currency || 'BDT',
        categoryId,
        data.note || '',
        data.date || new Date().toISOString().split('T')[0],
        hasReceipt,
        primaryReceiptUrl,
        initialStatus,
        justificationStatus,
        data.justificationReason || data.justification_reason || null,
        data.justificationComment || data.justification_comment || null,
        JSON.stringify(categoryDetails),
        baseAmount,
        vatRate,
        vatAmount,
        taxRate,
        taxAmount,
        receiptUrls,
        JSON.stringify(receiptPhotos),
      ],
    );

    const created = await this.findOne(res.rows[0].id);

    try {
      await this.auditLogsService.log(
        {
          action: 'EXPENSE_SUBMITTED',
          entityType: 'Expense',
          entityId: created.id,
          details: { amount: created.amount, category: created.categoryName, projectId: created.projectId },
        },
        user,
      );
    } catch (e) {
      console.error('Failed to log audit for expense create:', e);
    }

    // Notify all admins, project managers, and project members with can_approve_expenses
    try {
      const recipientsRes = await this.db.query(
        `SELECT DISTINCT u.id, u.email 
         FROM users u
         LEFT JOIN project_members pm ON pm.user_id = u.id AND pm.project_id = $2
         WHERE u.is_active = TRUE 
           AND u.id != $1
           AND (u.role IN ('main_admin', 'project_manager') OR pm.can_approve_expenses = TRUE)`,
        [employeeId, validProjectId],
      );
      const submitterRes = await this.db.query(
        `SELECT id, full_name, email, avatar_url FROM users WHERE id = $1`,
        [employeeId],
      );
      const submitter = submitterRes.rows[0];
      const submitterName = submitter?.full_name?.trim() || user?.name || user?.fullName || 'Team member';
      const submitterAvatar = submitter?.avatar_url || user?.avatarUrl || null;

      const expDateObj = new Date(created.date);
      const expenseDateFormatted = !isNaN(expDateObj.getTime())
        ? expDateObj.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
        : created.date;
      const submittedDateObj = new Date(created.createdAt || new Date());
      const submittedDateFormatted = !isNaN(submittedDateObj.getTime())
        ? submittedDateObj.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
        : 'Today';

      for (const recipient of recipientsRes.rows) {
        await this.notificationsService.create({
          userId: recipient.id,
          title: 'New Expense Submitted',
          message: `${submitterName} submitted a ${created.categoryName} expense of ${created.amount} ${created.currency} for ${created.projectName} (Expense Date: ${expenseDateFormatted} • Submitted: ${submittedDateFormatted}).`,
          fullExplanation: `${submitterName} submitted a new expense claim:\n• Category: ${created.categoryName}\n• Amount: ${created.amount} ${created.currency}\n• Project: ${created.projectName}\n• Expense Date: ${expenseDateFormatted}\n• Submitted On: ${submittedDateFormatted}\n\nPlease review and approve or reject from the Approvals section.`,
          type: 'expense_submitted',
          relatedProjectId: created.projectId,
          relatedExpenseId: created.id,
          actorId: employeeId,
          actorName: submitterName,
          actorAvatarUrl: submitterAvatar,
          expenseDate: expenseDateFormatted,
          submittedDate: submittedDateFormatted,
        });

        if (recipient.email) {
          await this.emailService.sendNewExpenseNotification(
            recipient.email,
            submitterName,
            created.amount,
            created.currency,
            created.categoryName,
            created.projectName,
            expenseDateFormatted,
            submittedDateFormatted
          );
        }
      }
    } catch (e) {
      console.error('Failed to send submission notifications:', e);
    }

    return created;
  }


  async update(id: string, data: any, user?: any) {
    const existing = await this.findOne(id, user);

    const isAdminOrFinance = user?.role === 'main_admin' || user?.role === 'admin' || user?.role === 'finance_manager' || user?.role === 'finance';
    const isProjectManager = user?.role === 'project_manager';
    const isOwner = existing.employeeId === user?.id;
    const isRejectedResubmission =
      existing.status === 'rejected' && isOwner &&
      (data.status === undefined || data.status === 'pending');

    if (user && !isAdminOrFinance && !isProjectManager) {
      if (existing.employeeId !== user.id) {
        throw new ForbiddenException('You can only edit your own expense reports');
      }
      if (existing.status !== 'pending' && existing.status !== 'draft' && existing.status !== 'rejected') {
        throw new ForbiddenException('Cannot edit an expense that has already been approved');
      }
    }

    if (data.status !== undefined) {
      if (data.status === 'approved') {
        return this.approve(id, user.id, data.approvalNote || data.note || 'Approved via update', user);
      }
      if (data.status === 'rejected') {
        const rejectionReason = data.rejectionReason || data.reason || data.note;
        return this.reject(id, user.id, rejectionReason, user);
      }
      const ownerKeepingPendingStatus =
        isOwner && existing.status === 'pending' && data.status === 'pending';
      if (!isAdminOrFinance && !isProjectManager &&
          !ownerKeepingPendingStatus && !isRejectedResubmission) {
        throw new ForbiddenException('You do not have permission to change expense status');
      }
    }

    const fields: string[] = [];
    const values: any[] = [];
    let idx = 1;

    // Resubmission of rejected expense
    if (isRejectedResubmission) {
      fields.push(`status = 'pending'`);
      fields.push(`rejection_reason = NULL`);
    }

    if (data.amount !== undefined) {
      fields.push(`amount = $${idx++}`);
      values.push(Number(data.amount));
    }
    if (data.note !== undefined) {
      fields.push(`note = $${idx++}`);
      values.push(data.note);
    }
    if (data.status !== undefined && !isRejectedResubmission) {
      fields.push(`status = $${idx++}`);
      values.push(data.status);
    }
    if (data.hasReceipt !== undefined || data.has_receipt !== undefined) {
      fields.push(`has_receipt = $${idx++}`);
      values.push(Boolean(data.hasReceipt ?? data.has_receipt));
    }
    if (data.receiptPhotoUrl !== undefined || data.receipt_photo_url !== undefined) {
      fields.push(`receipt_photo_url = $${idx++}`);
      values.push(data.receiptPhotoUrl ?? data.receipt_photo_url ?? null);
    }
    if (data.receiptPhotoUrls !== undefined || data.receipt_photo_urls !== undefined) {
      const urls = Array.isArray(data.receiptPhotoUrls)
        ? data.receiptPhotoUrls
        : (Array.isArray(data.receipt_photo_urls) ? data.receipt_photo_urls : []);
      fields.push(`receipt_photo_urls = $${idx++}`);
      values.push(urls);
      if (!data.receiptPhotoUrl && !data.receipt_photo_url && urls.length > 0) {
        fields.push(`receipt_photo_url = $${idx++}`);
        values.push(urls[0]);
      }
    }
    if (data.receiptPhotos !== undefined || data.receipt_photos !== undefined) {
      const photos = Array.isArray(data.receiptPhotos) ? data.receiptPhotos : (Array.isArray(data.receipt_photos) ? data.receipt_photos : []);
      fields.push(`receipt_photos = $${idx++}`);
      values.push(JSON.stringify(photos));
    }
    if (data.justificationStatus !== undefined || data.justification_status !== undefined) {
      fields.push(`justification_status = $${idx++}`);
      values.push(data.justificationStatus ?? data.justification_status);
    }
    if (data.baseAmount !== undefined || data.base_amount !== undefined || data.baseCost !== undefined || data.base_cost !== undefined) {
      fields.push(`base_amount = $${idx++}`);
      values.push(Number(data.baseAmount ?? data.base_amount ?? data.baseCost ?? data.base_cost));
    }
    if (data.vatRate !== undefined || data.vat_rate !== undefined) {
      fields.push(`vat_rate = $${idx++}`);
      values.push(Number(data.vatRate ?? data.vat_rate));
    }
    if (data.vatAmount !== undefined || data.vat_amount !== undefined) {
      fields.push(`vat_amount = $${idx++}`);
      values.push(Number(data.vatAmount ?? data.vat_amount));
    }
    if (data.taxRate !== undefined || data.tax_rate !== undefined) {
      fields.push(`tax_rate = $${idx++}`);
      values.push(Number(data.taxRate ?? data.tax_rate));
    }
    if (data.taxAmount !== undefined || data.tax_amount !== undefined) {
      fields.push(`tax_amount = $${idx++}`);
      values.push(Number(data.taxAmount ?? data.tax_amount));
    }
    if (data.categoryDetails !== undefined || data.category_details !== undefined) {
      fields.push(`category_details = $${idx++}`);
      values.push(JSON.stringify(data.categoryDetails ?? data.category_details ?? {}));
    }

    if (fields.length === 0) {
      return this.findOne(id, user);
    }

    values.push(id);
    await this.db.query(`UPDATE expenses SET ${fields.join(', ')} WHERE id = $${idx}`, values);
    const updated = await this.findOne(id, user);

    if (isRejectedResubmission) {
      try {
        const recipients = await this.db.query(
          `SELECT DISTINCT u.id
           FROM users u
           LEFT JOIN project_members pm
             ON pm.user_id = u.id AND pm.project_id = $2
           WHERE u.is_active = TRUE
             AND u.id != $1
             AND (u.role IN ('main_admin', 'admin', 'project_manager', 'finance', 'finance_manager')
                  OR pm.can_approve_expenses = TRUE)`,
          [updated.employeeId, updated.projectId],
        );
        await Promise.all(recipients.rows.map((recipient) =>
          this.notificationsService.create({
            userId: recipient.id,
            title: 'Expense Resubmitted',
            message: `${updated.employeeName} corrected and resubmitted a ${updated.categoryName} expense for ${updated.projectName}.`,
            fullExplanation: `${updated.employeeName} corrected and resubmitted their previously rejected expense claim. It is ready for review.`,
            type: 'expense_submitted',
            relatedProjectId: updated.projectId,
            relatedExpenseId: updated.id,
            actorId: updated.employeeId,
            actorName: updated.employeeName,
          }),
        ));
      } catch (error) {
        console.error('Failed to notify reviewers about expense resubmission:', error);
      }
    }

    try {
      await this.auditLogsService.log(
        {
          action: 'EXPENSE_UPDATED',
          entityType: 'Expense',
          entityId: id,
          details: { amount: updated.amount, projectId: updated.projectId, status: updated.status },
        },
        user,
      );
    } catch (_) {}

    return updated;
  }

  async delete(id: string, user?: any) {
    const exp = await this.findOne(id, user);
    const isAdmin = user?.role === 'main_admin' || user?.role === 'admin';
    if (!isAdmin) {
      if (exp.status !== 'pending' && exp.status !== 'draft' && exp.status !== 'rejected') {
        throw new ForbiddenException('Cannot delete an expense that has already been approved');
      }
      const isAssignedManager = user?.role === 'project_manager' && (user?.assignedProjectIds || []).includes(exp.projectId);
      const isOwner = exp.employeeId === user?.id;
      if (!isAssignedManager && !isOwner) {
        throw new ForbiddenException('You do not have permission to delete this expense');
      }
    }

    const res = await this.db.query('DELETE FROM expenses WHERE id = $1 RETURNING id', [id]);
    if (!res.rows.length) {
      throw new NotFoundException(`Expense not found: ${id}`);
    }
    try {
      await this.auditLogsService.log({
        action: 'EXPENSE_DELETED',
        entityType: 'Expense',
        entityId: id,
        details: { amount: exp.amount, projectId: exp.projectId },
      }, user);
    } catch (e) {
      console.error('Failed to log audit for expense delete:', e);
    }
    return { success: true, id };
  }

  async getComments(expenseId: string, user?: any) {
    await this.findOne(expenseId, user);
    const res = await this.db.query(
      `SELECT ec.id, ec.expense_id, ec.author_id,
              COALESCE(u.full_name, ec.author_name) AS author_name,
              COALESCE(u.role, ec.author_role) AS author_role,
              u.avatar_url AS author_avatar,
              ec.comment_text,
              ec.created_at
       FROM expense_comments ec
       LEFT JOIN users u ON u.id = ec.author_id
       WHERE ec.expense_id = $1
       ORDER BY ec.created_at ASC`,
      [expenseId],
    );
    return res.rows.map((c) => ({
      id: c.id,
      expenseId: c.expense_id,
      authorId: c.author_id,
      authorName: c.author_name || 'Team Member',
      userName: c.author_name || 'Team Member',
      user_name: c.author_name || 'Team Member',
      authorRole: c.author_role || 'Member',
      authorAvatar: c.author_avatar || null,
      avatarUrl: c.author_avatar || null,
      comment: c.comment_text || '',
      text: c.comment_text || '',
      createdAt: c.created_at,
    }));
  }

  async approve(id: string, reviewerId: string, note?: string, user?: any) {
    const exp = await this.findOne(id);
    if (exp.employeeId === reviewerId) {
      throw new ForbiddenException('Anti-fraud rule: You cannot approve your own expense report');
    }

    const projRes = await this.db.query('SELECT is_closed, status FROM projects WHERE id = $1', [exp.projectId]);
    if (
      projRes.rows.length &&
      (projRes.rows[0].is_closed === true ||
        (projRes.rows[0].status && ['closed', 'completed'].includes(projRes.rows[0].status.toLowerCase())))
    ) {
      throw new BadRequestException('Cannot approve expenses for a closed project');
    }

    const isGlobalAdmin = user?.role === 'main_admin' || user?.role === 'admin' || user?.role === 'project_manager';
    if (!isGlobalAdmin) {
      const pmRes = await this.db.query(
        'SELECT can_approve_expenses FROM project_members WHERE project_id = $1 AND user_id = $2',
        [exp.projectId, reviewerId]
      );
      if (!pmRes.rows.length || !pmRes.rows[0].can_approve_expenses) {
        throw new ForbiddenException('You do not have approval permission for this project');
      }
    }

    await this.db.query(
      `UPDATE expenses
       SET status = 'approved',
           justification_status = CASE WHEN has_receipt = FALSE THEN 'approved' ELSE justification_status END,
           justification_reviewed_by = $1,
           justification_review_comment = $2,
           justification_reviewed_at = NOW()
       WHERE id = $3`,
      [reviewerId, note || 'Approved by reviewer', id],
    );

    try {
      const reviewerRes = await this.db.query('SELECT full_name, role, avatar_url FROM users WHERE id = $1', [reviewerId]);
      const reviewer = reviewerRes.rows[0] || { full_name: 'Reviewer', role: 'project_manager' };

      await this.auditLogsService.log({
        userId: reviewerId,
        userName: reviewer.full_name,
        userRole: reviewer.role,
        action: 'EXPENSE_APPROVED',
        entityType: 'Expense',
        entityId: id,
        details: { note: note || '', amount: exp.amount },
      });

      await this.notificationsService.create({
        userId: exp.employeeId,
        title: 'Expense Approved',
        message: `Your expense report for ${exp.categoryName} (${exp.amount} ${exp.currency}) has been approved.`,
        type: 'expense_approved',
        relatedProjectId: exp.projectId,
        relatedExpenseId: id,
        actorId: reviewerId,
        actorName: reviewer.full_name,
        actorAvatarUrl: reviewer.avatar_url || null,
      });
    } catch (e) {
      console.error('Failed to process audit/notification for expense approve:', e);
    }

    return this.findOne(id);
  }

  async reject(id: string, reviewerId: string, reason: string, user?: any) {
    if (!reason || typeof reason !== 'string' || reason.trim().length === 0) {
      throw new BadRequestException('A reason is mandatory when rejecting an expense claim');
    }
    const cleanReason = reason.trim();

    const exp = await this.findOne(id);
    if (exp.employeeId === reviewerId) {
      throw new ForbiddenException('Anti-fraud rule: You cannot reject your own expense report');
    }

    const isGlobalAdmin = user?.role === 'main_admin' || user?.role === 'admin' || user?.role === 'project_manager';
    if (!isGlobalAdmin) {
      const pmRes = await this.db.query(
        'SELECT can_approve_expenses FROM project_members WHERE project_id = $1 AND user_id = $2',
        [exp.projectId, reviewerId]
      );
      if (!pmRes.rows.length || !pmRes.rows[0].can_approve_expenses) {
        throw new ForbiddenException('You do not have approval permission for this project');
      }
    }

    await this.db.query(
      `UPDATE expenses
       SET status = 'rejected',
           rejection_reason = $1,
           justification_status = CASE WHEN has_receipt = FALSE THEN 'rejected' ELSE justification_status END,
           justification_reviewed_by = $2,
           justification_reviewed_at = NOW()
       WHERE id = $3`,
      [cleanReason, reviewerId, id],
    );

    try {
      const reviewerRes = await this.db.query('SELECT full_name, role, avatar_url FROM users WHERE id = $1', [reviewerId]);
      const reviewer = reviewerRes.rows[0] || { full_name: 'Reviewer', role: 'project_manager' };

      await this.auditLogsService.log({
        userId: reviewerId,
        userName: reviewer.full_name,
        userRole: reviewer.role,
        action: 'EXPENSE_REJECTED',
        entityType: 'Expense',
        entityId: id,
        details: { reason: cleanReason, amount: exp.amount },
      });

      await this.notificationsService.create({
        userId: exp.employeeId,
        title: 'Expense Rejected',
        message: `Your expense report for ${exp.categoryName} (${exp.amount} ${exp.currency}) was rejected. Reason: ${cleanReason}`,
        fullExplanation: `Your expense report was rejected. Reason: ${cleanReason}`,
        rejectionReason: cleanReason,
        type: 'expense_rejected',
        relatedProjectId: exp.projectId,
        relatedExpenseId: id,
        actorId: reviewerId,
        actorName: reviewer.full_name,
        actorAvatarUrl: reviewer.avatar_url || null,
      });
    } catch (e) {
      console.error('Failed to process audit/notification for expense reject:', e);
    }

    return this.findOne(id);
  }

  async addComment(expenseId: string, authorId: string, rawComment: string) {
    const comment = (rawComment || '').trim();
    if (!comment) {
      throw new BadRequestException('Comment text cannot be empty');
    }

    const userRes = await this.db.query('SELECT full_name, role, avatar_url FROM users WHERE id = $1', [authorId]);
    const userRow = userRes.rows[0] || {};
    const authorName = userRow.full_name || 'Team Member';
    const authorRole = userRow.role || 'project_member';
    const authorAvatar = userRow.avatar_url || null;
    const res = await this.db.query(
      `INSERT INTO expense_comments (expense_id, author_id, author_name, author_role, comment_text)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, expense_id, author_id, author_name, author_role, comment_text, created_at`,
      [expenseId, authorId, authorName, authorRole, comment],
    );

    const commentRow = res.rows[0];

    // Notification & FCM Push Notification: notify the counterparty
    try {
      const expRes = await this.db.query(
        `SELECT e.id, e.employee_id, e.project_id, e.amount, e.currency,
                c.name AS category_name, p.name AS project_name, u.full_name AS employee_name
         FROM expenses e
         LEFT JOIN categories c ON c.id = e.category_id
         LEFT JOIN projects p ON p.id = e.project_id
         LEFT JOIN users u ON u.id = e.employee_id
         WHERE e.id = $1`,
        [expenseId],
      );

      if (expRes.rows.length > 0) {
        const exp = expRes.rows[0];
        const isAuthorTheEmployee = authorId === exp.employee_id;

        if (isAuthorTheEmployee) {
          // Employee replied -> notify project managers and global admins
          const managersRes = await this.db.query(
            `SELECT user_id FROM project_members 
             WHERE project_id = $1 AND (can_approve_expenses = TRUE OR role_in_project ILIKE '%Manager%' OR role_in_project ILIKE '%Lead%')`,
            [exp.project_id],
          );
          const recipientIds = new Set<string>(managersRes.rows.map((r: any) => r.user_id));

          // Also notify global admins
          const adminsRes = await this.db.query(
            `SELECT id FROM users WHERE role IN ('main_admin', 'admin', 'finance')`,
          );
          adminsRes.rows.forEach((r: any) => recipientIds.add(r.id));
          recipientIds.delete(authorId); // Do not notify sender

          for (const recipientId of recipientIds) {
            await this.notificationsService.create({
              userId: recipientId,
              title: `Clarification Reply: ${exp.category_name || 'Expense'}`,
              message: `${authorName}: "${comment.length > 90 ? comment.substring(0, 87) + '...' : comment}"`,
              fullExplanation: `Clarification response posted by ${authorName} for expense ${exp.category_name || ''} (${exp.amount} ${exp.currency || 'BDT'}) under project ${exp.project_name || ''}.`,
              type: 'comment_added',
              relatedProjectId: exp.project_id,
              relatedExpenseId: expenseId,
              actorId: authorId,
              actorName: authorName,
            });
          }
        } else {
          // Reviewer/Admin commented -> notify the claimant employee directly
          await this.notificationsService.create({
            userId: exp.employee_id,
            title: `Clarification Needed: ${exp.category_name || 'Expense'}`,
            message: `${authorName}: "${comment.length > 90 ? comment.substring(0, 87) + '...' : comment}"`,
            fullExplanation: `${authorName} requested clarification or posted a remark on your ${exp.category_name || 'expense'} claim (${exp.amount} ${exp.currency || 'BDT'}). Click to view and reply.`,
            type: 'comment_added',
            relatedProjectId: exp.project_id,
            relatedExpenseId: expenseId,
            actorId: authorId,
            actorName: authorName,
          });
        }
      }
    } catch (notifErr) {
      console.error('Failed to dispatch notification for clarification comment:', notifErr);
    }

    return {
      id: commentRow.id,
      expenseId: commentRow.expense_id,
      authorId: commentRow.author_id,
      authorName: commentRow.author_name,
      userName: commentRow.author_name,
      user_name: commentRow.author_name,
      authorRole: commentRow.author_role,
      authorAvatar: authorAvatar,
      avatarUrl: authorAvatar,
      comment: commentRow.comment_text,
      text: commentRow.comment_text,
      createdAt: commentRow.created_at,
    };
  }

  async submitJustification(id: string, userId: string, data: any) {
    const res = await this.db.query(
      `UPDATE expenses
       SET justification_status = 'submitted',
           justification_reason = $1,
           justification_comment = $2,
           justification_attachment_url = $3,
           updated_at = NOW()
       WHERE id = $4
       RETURNING *`,
      [
        data.justificationReason || data.justification_reason || '',
        data.justificationComment || data.justification_comment || null,
        data.justificationAttachmentUrl || data.justification_attachment_url || null,
        id,
      ],
    );
    if (!res.rows.length) {
      throw new NotFoundException(`Expense ${id} not found`);
    }
    return this.findOne(id);
  }

  async reviewJustification(id: string, reviewerId: string, data: any) {
    const res = await this.db.query(
      `UPDATE expenses
       SET justification_status = $1,
           justification_review_comment = $2,
           justification_reviewed_by = $3,
           justification_reviewed_at = NOW(),
           updated_at = NOW()
       WHERE id = $4
       RETURNING *`,
      [
        data.status || 'approved',
        data.comment || data.justificationReviewComment || null,
        reviewerId,
        id,
      ],
    );
    if (!res.rows.length) {
      throw new NotFoundException(`Expense ${id} not found`);
    }
    return this.findOne(id);
  }
}
