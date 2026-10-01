import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { AuditLogsService } from '../audit-logs/audit-logs.service';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class ExpensesService {
  constructor(
    private readonly db: DatabaseService,
    private readonly auditLogsService: AuditLogsService,
    private readonly notificationsService: NotificationsService,
  ) {}

  private mapExpenseRow(e: any, comments: any[] = []) {
    const details = typeof e.category_details === 'string' ? JSON.parse(e.category_details) : e.category_details || {};

    return {
      id: e.id,
      employeeId: e.employee_id,
      employeeName: e.employee_name || 'Team Member',
      projectId: e.project_id,
      projectName: e.project_name || 'Project',
      taskId: e.task_id,
      amount: Number(e.amount),
      officeBenefitAmount: Number(e.office_benefit_amount),
      currency: e.currency,
      categoryId: e.category_id,
      categoryName: e.category_name || 'Category',
      categoryIcon: e.category_icon || 'expense',
      note: e.note || '',
      date: e.date,
      hasReceipt: Boolean(e.has_receipt),
      receiptPhotoUrl: e.receipt_photo_url,
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
      comments: comments.map((c) => ({
        id: c.id,
        expenseId: c.expense_id,
        authorId: c.author_id,
        authorName: c.author_name || 'User',
        authorRole: c.author_role || 'Member',
        comment: c.comment_text || c.comment || '',
        createdAt: c.created_at,
      })),
    };
  }

  async findAll(query: { projectId?: string; employeeId?: string; status?: string }, user: any) {
    let sql = `
      SELECT e.*,
        u.full_name AS employee_name,
        p.name AS project_name,
        c.name AS category_name,
        c.icon_name AS category_icon,
        COALESCE(
          (SELECT json_agg(json_build_object(
            'id', ec.id, 'expense_id', ec.expense_id, 'author_id', ec.author_id,
            'author_name', ec.author_name, 'author_role', ec.author_role, 'comment_text', ec.comment_text,
            'created_at', ec.created_at
          ))
          FROM expense_comments ec
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

    // PRD Access control: regular member only sees their own expenses unless project manager/admin/finance
    if (user.role === 'project_member') {
      sql += ` AND (e.employee_id = $${idx++} OR EXISTS (SELECT 1 FROM project_members pm WHERE pm.project_id = e.project_id AND pm.user_id = '${user.id}' AND pm.role_in_project ILIKE '%Manager%'))`;
      params.push(user.id);
    } else if (user.role === 'project_manager') {
      sql += ` AND EXISTS (SELECT 1 FROM project_members pm WHERE pm.project_id = e.project_id AND pm.user_id = $${idx++})`;
      params.push(user.id);
    }

    if (query.projectId) {
      sql += ` AND (e.project_id = $${idx} OR p.project_code = $${idx})`;
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

  async findOne(id: string) {
    const sql = `
      SELECT e.*,
        u.full_name AS employee_name,
        p.name AS project_name,
        c.name AS category_name,
        c.icon_name AS category_icon,
        COALESCE(
          (SELECT json_agg(json_build_object(
            'id', ec.id, 'expense_id', ec.expense_id, 'author_id', ec.author_id,
            'author_name', ec.author_name, 'author_role', ec.author_role, 'comment_text', ec.comment_text,
            'created_at', ec.created_at
          ))
          FROM expense_comments ec
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

    return this.mapExpenseRow(res.rows[0], res.rows[0].comments);
  }

  async create(data: any, user: any) {
    const isAdmin = user?.role === 'main_admin';
    const employeeId = (isAdmin && (data.employeeId || data.employee_id)) ? (data.employeeId || data.employee_id) : user.id;
    const initialStatus = (isAdmin && data.status) ? data.status : 'pending';

    let categoryId = data.categoryId || data.category_id;
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!categoryId || !uuidRegex.test(categoryId)) {
      const cleanSlug = (categoryId || '').toString().replace(/^cat_/, '');
      const catRes = await this.db.query(
        'SELECT id FROM categories WHERE slug ILIKE $1 OR name ILIKE $1 OR slug ILIKE $2 OR name ILIKE $2 LIMIT 1',
        [categoryId || '', cleanSlug],
      );
      if (catRes.rows.length) {
        categoryId = catRes.rows[0].id;
      } else {
        const firstCat = await this.db.query('SELECT id FROM categories LIMIT 1');
        if (firstCat.rows.length) categoryId = firstCat.rows[0].id;
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

    const res = await this.db.query(
      `INSERT INTO expenses (
        employee_id, project_id, task_id, amount, currency, category_id,
        note, date, has_receipt, receipt_photo_url, status,
        justification_status, justification_reason, justification_comment,
        category_details
      ) VALUES (
        $1, $2, $3, $4, $5, $6,
        $7, $8, $9, $10, $11,
        $12, $13, $14,
        $15
      ) RETURNING id`,
      [
        employeeId,
        data.projectId || data.project_id,
        data.taskId || data.task_id || null,
        Number(data.amount),
        data.currency || 'BDT',
        categoryId,
        data.note || '',
        data.date || new Date().toISOString().split('T')[0],
        hasReceipt,
        data.receiptPhotoUrl || data.receipt_photo_url || null,
        initialStatus,
        justificationStatus,
        data.justificationReason || data.justification_reason || null,
        data.justificationComment || data.justification_comment || null,
        JSON.stringify(categoryDetails),
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

    return created;
  }

  async update(id: string, data: any) {
    const fields: string[] = [];
    const values: any[] = [];
    let idx = 1;

    if (data.amount !== undefined) {
      fields.push(`amount = $${idx++}`);
      values.push(Number(data.amount));
    }
    if (data.note !== undefined) {
      fields.push(`note = $${idx++}`);
      values.push(data.note);
    }
    if (data.status !== undefined) {
      fields.push(`status = $${idx++}`);
      values.push(data.status);
    }
    if (data.hasReceipt !== undefined || data.has_receipt !== undefined) {
      fields.push(`has_receipt = $${idx++}`);
      values.push(Boolean(data.hasReceipt ?? data.has_receipt));
    }

    if (fields.length === 0) {
      return this.findOne(id);
    }

    values.push(id);
    await this.db.query(`UPDATE expenses SET ${fields.join(', ')} WHERE id = $${idx}`, values);
    return this.findOne(id);
  }

  async delete(id: string) {
    const exp = await this.findOne(id);
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
      });
    } catch (e) {
      console.error('Failed to log audit for expense delete:', e);
    }
    return { success: true, id };
  }

  async approve(id: string, reviewerId: string, note?: string) {
    const exp = await this.findOne(id);
    if (exp.employeeId === reviewerId) {
      throw new ForbiddenException('Anti-fraud rule: You cannot approve your own expense report');
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
      const reviewerRes = await this.db.query('SELECT full_name, role FROM users WHERE id = $1', [reviewerId]);
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
      });
    } catch (e) {
      console.error('Failed to process audit/notification for expense approve:', e);
    }

    return this.findOne(id);
  }

  async reject(id: string, reviewerId: string, reason: string) {
    const exp = await this.findOne(id);

    await this.db.query(
      `UPDATE expenses
       SET status = 'rejected',
           rejection_reason = $1,
           justification_status = CASE WHEN has_receipt = FALSE THEN 'rejected' ELSE justification_status END,
           justification_reviewed_by = $2,
           justification_reviewed_at = NOW()
       WHERE id = $3`,
      [reason || 'Rejected by reviewer', reviewerId, id],
    );

    try {
      const reviewerRes = await this.db.query('SELECT full_name, role FROM users WHERE id = $1', [reviewerId]);
      const reviewer = reviewerRes.rows[0] || { full_name: 'Reviewer', role: 'project_manager' };

      await this.auditLogsService.log({
        userId: reviewerId,
        userName: reviewer.full_name,
        userRole: reviewer.role,
        action: 'EXPENSE_REJECTED',
        entityType: 'Expense',
        entityId: id,
        details: { reason, amount: exp.amount },
      });

      await this.notificationsService.create({
        userId: exp.employeeId,
        title: 'Expense Rejected',
        message: `Your expense report for ${exp.categoryName} (${exp.amount} ${exp.currency}) was rejected. Reason: ${reason || 'None specified'}`,
        type: 'expense_rejected',
        relatedProjectId: exp.projectId,
        relatedExpenseId: id,
      });
    } catch (e) {
      console.error('Failed to process audit/notification for expense reject:', e);
    }

    return this.findOne(id);
  }

  async addComment(expenseId: string, authorId: string, comment: string) {
    const userRes = await this.db.query('SELECT full_name, role FROM users WHERE id = $1', [authorId]);
    const userRow = userRes.rows[0] || {};
    const authorName = userRow.full_name || 'Team Member';
    const authorRole = userRow.role || 'project_member';

    const res = await this.db.query(
      `INSERT INTO expense_comments (expense_id, author_id, author_name, author_role, comment_text)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, expense_id, author_id, author_name, author_role, comment_text, created_at`,
      [expenseId, authorId, authorName, authorRole, comment],
    );

    return {
      id: res.rows[0].id,
      expenseId: res.rows[0].expense_id,
      authorId: res.rows[0].author_id,
      authorName: res.rows[0].author_name,
      authorRole: res.rows[0].author_role,
      comment: res.rows[0].comment_text,
      createdAt: res.rows[0].created_at,
    };
  }
}
