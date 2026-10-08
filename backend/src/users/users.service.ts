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
      SELECT id, email, full_name, role, department, designation, phone, avatar_url, is_active
      FROM users
      WHERE 1=1
    `;
    const params: any[] = [];

    if (query && query.trim().length > 0) {
      sql += ` AND (full_name ILIKE $1 OR email ILIKE $1)`;
      params.push(`%${query.trim()}%`);
    }

    sql += ` ORDER BY full_name ASC`;

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
    }));
  }

  async findByEmail(email: string) {
    const res = await this.db.query(
      `SELECT id, email, full_name, role, department, designation, phone, avatar_url, is_active
       FROM users
       WHERE email = $1`,
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
    };
  }

  async findOne(id: string) {
    const res = await this.db.query(
      `SELECT id, email, full_name, role, department, designation, phone, avatar_url, is_active
       FROM users
       WHERE id = $1`,
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

    if (!fields.length) return this.findOne(id);

    fields.push(`updated_at = NOW()`);
    values.push(id);

    await this.db.query(
      `UPDATE users SET ${fields.join(', ')} WHERE id = $${idx}`,
      values,
    );
    return this.findOne(id);
  }

  async updateRole(id: string, role: string) {
    await this.db.query(
      `UPDATE users SET role = $1, updated_at = NOW() WHERE id = $2`,
      [role, id],
    );
    return this.findOne(id);
  }

  async updateStatus(id: string, isActive: boolean) {
    await this.db.query(
      `UPDATE users SET is_active = $1, updated_at = NOW() WHERE id = $2`,
      [isActive, id],
    );
    return this.findOne(id);
  }

  async delete(id: string) {
    await this.db.query(
      `UPDATE users SET is_active = FALSE, updated_at = NOW() WHERE id = $1`,
      [id],
    );
    return { success: true };
  }

  async saveFcmToken(userId: string, token: string, deviceInfo?: string) {
    return this.fcmService.saveToken(userId, token, deviceInfo);
  }
}
