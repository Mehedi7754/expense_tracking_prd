import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { FcmService } from '../notifications/fcm.service';
import * as bcrypt from 'bcryptjs';

@Injectable()
export class UsersService {
  constructor(
    private readonly db: DatabaseService,
    private readonly fcmService: FcmService,
  ) {}

  async findAll(query?: string) {
    let sql = `
      SELECT u.id, u.email, u.full_name, u.role, u.department, u.designation, u.phone, u.avatar_url, u.is_active,
             COALESCE(ARRAY_AGG(pm.project_id) FILTER (WHERE pm.project_id IS NOT NULL), '{}') AS assigned_project_ids
      FROM users u
      LEFT JOIN project_members pm ON pm.user_id = u.id
      WHERE u.is_active = TRUE
    `;
    const params: any[] = [];

    if (query && query.trim().length > 0) {
      sql += ` AND (u.full_name ILIKE $1 OR u.email ILIKE $1)`;
      params.push(`%${query.trim()}%`);
    }

    sql += ` GROUP BY u.id ORDER BY u.full_name ASC`;

    const res = await this.db.query(sql, params);
    return res.rows.map((r) => ({
      id: r.id,
      name: r.full_name,
      email: r.email,
      role: r.role,
      department: r.department || '',
      designation: r.designation || '',
      phone: r.phone || '',
      avatarUrl: r.avatar_url,
      isActive: r.is_active,
      assignedProjectIds: r.assigned_project_ids || [],
      assigned_project_ids: r.assigned_project_ids || [],
    }));
  }

  async findByEmail(email: string) {
    const res = await this.db.query(
      `SELECT u.id, u.email, u.full_name, u.role, u.department, u.designation, u.phone, u.avatar_url, u.is_active,
              COALESCE(ARRAY_AGG(pm.project_id) FILTER (WHERE pm.project_id IS NOT NULL), '{}') AS assigned_project_ids
       FROM users u
       LEFT JOIN project_members pm ON pm.user_id = u.id
       WHERE u.email = $1
       GROUP BY u.id`,
      [email.trim().toLowerCase()],
    );

    if (!res.rows.length) return null;
    const r = res.rows[0];
    return {
      id: r.id,
      name: r.full_name,
      email: r.email,
      role: r.role,
      department: r.department || '',
      designation: r.designation || '',
      phone: r.phone || '',
      avatarUrl: r.avatar_url,
      isActive: r.is_active,
      assignedProjectIds: r.assigned_project_ids || [],
      assigned_project_ids: r.assigned_project_ids || [],
    };
  }

  async findOne(id: string) {
    const res = await this.db.query(
      `SELECT u.id, u.email, u.full_name, u.role, u.department, u.designation, u.phone, u.avatar_url, u.is_active,
              COALESCE(ARRAY_AGG(pm.project_id) FILTER (WHERE pm.project_id IS NOT NULL), '{}') AS assigned_project_ids
       FROM users u
       LEFT JOIN project_members pm ON pm.user_id = u.id
       WHERE u.id = $1
       GROUP BY u.id`,
      [id],
    );
    if (!res.rows.length) return null;
    const r = res.rows[0];
    return {
      id: r.id,
      name: r.full_name,
      email: r.email,
      role: r.role,
      department: r.department || '',
      designation: r.designation || '',
      phone: r.phone || '',
      avatarUrl: r.avatar_url,
      isActive: r.is_active,
      assignedProjectIds: r.assigned_project_ids || [],
      assigned_project_ids: r.assigned_project_ids || [],
    };
  }

  async create(data: any, creator?: any) {
    const email = (data.email || '').trim().toLowerCase();
    const fullName = data.name || data.fullName || data.full_name || email.split('@')[0];
    let rawRole = (data.role || 'project_member').toString();
    const cleanRole = rawRole.toLowerCase().replace(/_/g, '');
    let role = 'project_member';
    if (cleanRole === 'mainadmin' || cleanRole === 'admin') {
      role = 'main_admin';
    } else if (cleanRole === 'projectmanager' || cleanRole === 'manager') {
      role = 'project_manager';
    } else if (cleanRole === 'finance') {
      role = 'finance';
    } else if (cleanRole === 'viewer') {
      role = 'viewer';
    } else {
      role = 'project_member';
    }
    
    // Strict Role Hierarchy: Only main_admin can create/assign main_admin
    const creatorRole = creator?.role?.replace(/_/g, '').toLowerCase();
    if (role === 'main_admin') {
      if (creatorRole !== 'mainadmin') {
        throw new ForbiddenException('Only Super Admin can assign the Admin / Super Admin role.');
      }
    }

    const department = data.department || '';
    const designation = data.designation || '';
    const phone = data.phone || '';
    const passwordHash = await bcrypt.hash(data.password || 'password123', 10);

    const res = await this.db.query(
      `INSERT INTO users (email, password_hash, full_name, role, department, designation, phone, is_active)
       VALUES ($1, $2, $3, $4, $5, $6, $7, TRUE)
       ON CONFLICT (email) DO UPDATE
       SET full_name = EXCLUDED.full_name,
           password_hash = EXCLUDED.password_hash,
           role = EXCLUDED.role,
           department = EXCLUDED.department,
           designation = EXCLUDED.designation,
           phone = EXCLUDED.phone,
           is_active = TRUE,
           updated_at = NOW()
       RETURNING id, email, full_name, role, department, designation, phone, avatar_url, is_active`,
      [email, passwordHash, fullName, role, department, designation, phone],
    );
    const r = res.rows[0];
    return {
      id: r.id,
      name: r.full_name,
      email: r.email,
      role: r.role,
      department: r.department || '',
      designation: r.designation || '',
      phone: r.phone || '',
      avatarUrl: r.avatar_url,
      isActive: r.is_active,
    };
  }

  async update(id: string, data: any, updater?: any) {
    const clean = (id || '').trim();
    const userRes = await this.db.query(
      `SELECT id FROM users WHERE id::text = $1 OR email ILIKE $1 LIMIT 1`,
      [clean],
    );
    if (!userRes.rows.length) {
      throw new NotFoundException('User not found');
    }
    const targetId = userRes.rows[0].id;

    const fields: string[] = [];
    const values: any[] = [];
    let idx = 1;

    if (data.name || data.fullName || data.full_name) {
      fields.push(`full_name = $${idx++}`);
      values.push(data.name || data.fullName || data.full_name);
    }
    if (data.email !== undefined && typeof data.email === 'string' && data.email.trim().length > 0) {
      fields.push(`email = $${idx++}`);
      values.push(data.email.trim().toLowerCase());
    }
    if (data.role) {
      const rawTarget = data.role.toString();
      const cleanTarget = rawTarget.toLowerCase().replace(/_/g, '');
      let mappedRole = 'project_member';
      if (cleanTarget === 'mainadmin' || cleanTarget === 'admin') {
        mappedRole = 'main_admin';
      } else if (cleanTarget === 'projectmanager' || cleanTarget === 'manager') {
        mappedRole = 'project_manager';
      } else if (cleanTarget === 'finance') {
        mappedRole = 'finance';
      } else if (cleanTarget === 'viewer') {
        mappedRole = 'viewer';
      } else {
        mappedRole = 'project_member';
      }

      const updaterRole = updater?.role?.replace(/_/g, '').toLowerCase();
      if (mappedRole === 'main_admin') {
        if (updaterRole !== 'mainadmin') {
          throw new ForbiddenException('Only Super Admin can assign the Admin / Super Admin role.');
        }
      }
      fields.push(`role = $${idx++}`);
      values.push(mappedRole);
    }
    if (data.department !== undefined) {
      fields.push(`department = $${idx++}`);
      values.push(data.department);
    }
    if (data.designation !== undefined) {
      fields.push(`designation = $${idx++}`);
      values.push(data.designation);
    }
    if (data.phone !== undefined) {
      fields.push(`phone = $${idx++}`);
      values.push(data.phone);
    }
    if (data.password && typeof data.password === 'string' && data.password.trim().length > 0) {
      const passwordHash = await bcrypt.hash(data.password.trim(), 10);
      fields.push(`password_hash = $${idx++}`);
      values.push(passwordHash);
    }
    if (data.isActive !== undefined || data.is_active !== undefined) {
      fields.push(`is_active = $${idx++}`);
      values.push(data.isActive ?? data.is_active);
    }
    if (data.avatarUrl !== undefined || data.avatar_url !== undefined) {
      fields.push(`avatar_url = $${idx++}`);
      values.push(data.avatarUrl ?? data.avatar_url);
    }

    if (!fields.length) return this.findOne(targetId);

    fields.push(`updated_at = NOW()`);
    values.push(targetId);

    await this.db.query(
      `UPDATE users SET ${fields.join(', ')} WHERE id = $${idx}`,
      values,
    );
    return this.findOne(targetId);
  }

  async updateRole(id: string, role: string) {
    const userRes = await this.db.query(
      `SELECT id FROM users WHERE id::text = $1 OR email ILIKE $1 LIMIT 1`,
      [id.trim()],
    );
    if (!userRes.rows.length) return null;
    const targetId = userRes.rows[0].id;
    await this.db.query(
      `UPDATE users SET role = $1, updated_at = NOW() WHERE id = $2`,
      [role, targetId],
    );
    return this.findOne(targetId);
  }

  async updateStatus(id: string, isActive: boolean) {
    const userRes = await this.db.query(
      `SELECT id FROM users WHERE id::text = $1 OR email ILIKE $1 LIMIT 1`,
      [id.trim()],
    );
    if (!userRes.rows.length) return null;
    const targetId = userRes.rows[0].id;
    await this.db.query(
      `UPDATE users SET is_active = $1, updated_at = NOW() WHERE id = $2`,
      [isActive, targetId],
    );
    return this.findOne(targetId);
  }

  async delete(id: string) {
    const clean = (id || '').trim();
    if (!clean) return { success: false, message: 'Invalid ID' };

    const userRes = await this.db.query(
      `SELECT id, email FROM users WHERE id::text = $1 OR email ILIKE $1 LIMIT 1`,
      [clean],
    );
    if (!userRes.rows.length) {
      return { success: true, message: 'User already deleted or not found' };
    }
    const targetId = userRes.rows[0].id;

    // Check if user has historical expenses (accounting ledger integrity)
    const expRes = await this.db.query(
      `SELECT 1 FROM expenses WHERE employee_id = $1 LIMIT 1`,
      [targetId],
    );

    if (expRes.rows.length > 0) {
      // Historical financial records exist: deactivate user so they are hidden from all active UI and can never log in
      await this.db.query(
        `UPDATE users SET is_active = FALSE, updated_at = NOW() WHERE id = $1`,
        [targetId],
      );
      await this.db.query(`DELETE FROM project_members WHERE user_id = $1`, [targetId]).catch(() => {});
      await this.db.query(`DELETE FROM fcm_tokens WHERE user_id = $1`, [targetId]).catch(() => {});
    } else {
      // No ledger locks: perform complete permanent cascade deletion
      await this.db.query(`DELETE FROM attendance_records WHERE user_id = $1`, [targetId]).catch(() => {});
      await this.db.query(`DELETE FROM employee_salaries WHERE user_id = $1`, [targetId]).catch(() => {});
      await this.db.query(`DELETE FROM project_members WHERE user_id = $1`, [targetId]).catch(() => {});
      await this.db.query(`DELETE FROM chat_messages WHERE sender_id = $1`, [targetId]).catch(() => {});
      await this.db.query(`DELETE FROM notifications WHERE user_id = $1`, [targetId]).catch(() => {});
      await this.db.query(`DELETE FROM fcm_tokens WHERE user_id = $1`, [targetId]).catch(() => {});
      await this.db.query(`UPDATE tasks SET assignee_id = NULL WHERE assignee_id = $1`, [targetId]).catch(() => {});
      await this.db.query(`UPDATE projects SET created_by = NULL WHERE created_by = $1`, [targetId]).catch(() => {});

      try {
        await this.db.query(`DELETE FROM users WHERE id = $1`, [targetId]);
      } catch (_) {
        await this.db.query(
          `UPDATE users SET is_active = FALSE, updated_at = NOW() WHERE id = $1`,
          [targetId],
        );
      }
    }

    return { success: true, id: targetId };
  }

  async saveFcmToken(userId: string, token: string, deviceInfo?: string) {
    return this.fcmService.saveToken(userId, token, deviceInfo);
  }
}
