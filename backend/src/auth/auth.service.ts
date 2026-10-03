import { Injectable, UnauthorizedException, ConflictException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { DatabaseService } from '../database/database.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';

@Injectable()
export class AuthService {
  constructor(
    private readonly db: DatabaseService,
    private readonly jwtService: JwtService,
  ) {}

  private mapRole(role: string): string {
    const clean = role.toLowerCase().replace(/_/g, '');
    switch (clean) {
      case 'mainadmin':
      case 'admin':
        return 'main_admin';
      case 'projectmanager':
      case 'manager':
        return 'project_manager';
      case 'projectmember':
      case 'member':
      case 'employee':
        return 'project_member';
      case 'finance':
        return 'finance';
      case 'viewer':
        return 'viewer';
      default:
        return 'project_member';
    }
  }

  async login(dto: LoginDto) {
    const res = await this.db.query(
      `SELECT u.id, u.email, u.password_hash, u.full_name, u.role, u.department, u.designation, u.phone, u.avatar_url,
              COALESCE(ARRAY_AGG(pm.project_id) FILTER (WHERE pm.project_id IS NOT NULL), '{}') AS assigned_project_ids
       FROM users u
       LEFT JOIN project_members pm ON pm.user_id = u.id
       WHERE u.email = $1 AND u.is_active = TRUE
       GROUP BY u.id`,
      [dto.email.trim().toLowerCase()],
    );

    if (!res.rows.length) {
      throw new UnauthorizedException('Invalid email or password');
    }

    const userRow = res.rows[0];
    const isPasswordValid = await bcrypt.compare(dto.password, userRow.password_hash);
    if (!isPasswordValid) {
      throw new UnauthorizedException('Invalid email or password');
    }

    const payload = { sub: userRow.id, email: userRow.email, role: userRow.role };
    const token = this.jwtService.sign(payload);

    const user = {
      id: userRow.id,
      name: userRow.full_name,
      email: userRow.email,
      role: userRow.role,
      department: userRow.department,
      designation: userRow.designation,
      phone: userRow.phone,
      avatarUrl: userRow.avatar_url,
      assignedProjectIds: userRow.assigned_project_ids,
    };

    return {
      token,
      accessToken: token,
      user,
    };
  }

  async register(dto: RegisterDto) {
    throw new ForbiddenException(
      'Public registration is disabled. All employee and manager accounts must be created by an authorized Admin or Super Admin.',
    );
  }

  async getProfile(userId: string) {
    const res = await this.db.query(
      `SELECT u.id, u.email, u.full_name, u.role, u.department, u.designation, u.phone, u.avatar_url,
              COALESCE(ARRAY_AGG(pm.project_id) FILTER (WHERE pm.project_id IS NOT NULL), '{}') AS assigned_project_ids
       FROM users u
       LEFT JOIN project_members pm ON pm.user_id = u.id
       WHERE u.id = $1 AND u.is_active = TRUE
       GROUP BY u.id`,
      [userId],
    );

    if (!res.rows.length) {
      throw new UnauthorizedException('User not found');
    }

    const row = res.rows[0];
    return {
      id: row.id,
      name: row.full_name,
      email: row.email,
      role: row.role,
      department: row.department,
      designation: row.designation,
      phone: row.phone,
      avatarUrl: row.avatar_url,
      assignedProjectIds: row.assigned_project_ids,
    };
  }

  async updateProfile(userId: string, data: any) {
    const fields: string[] = [];
    const values: any[] = [];
    let idx = 1;

    if (data.avatarUrl !== undefined || data.avatar_url !== undefined) {
      fields.push(`avatar_url = $${idx++}`);
      values.push(data.avatarUrl ?? data.avatar_url);
    }
    if (data.name !== undefined || data.full_name !== undefined) {
      fields.push(`full_name = $${idx++}`);
      values.push(data.name ?? data.full_name);
    }
    if (data.email !== undefined && typeof data.email === 'string' && data.email.trim().length > 0) {
      fields.push(`email = $${idx++}`);
      values.push(data.email.trim().toLowerCase());
    }
    if (data.phone !== undefined) {
      fields.push(`phone = $${idx++}`);
      values.push(data.phone);
    }
    if (data.designation !== undefined) {
      fields.push(`designation = $${idx++}`);
      values.push(data.designation);
    }
    if (data.department !== undefined) {
      fields.push(`department = $${idx++}`);
      values.push(data.department);
    }

    if (!fields.length) {
      return this.getProfile(userId);
    }

    values.push(userId);
    const sql = `UPDATE users SET ${fields.join(', ')} WHERE id = $${idx} RETURNING id, email, full_name, role, department, designation, phone, avatar_url`;
    const res = await this.db.query(sql, values);
    if (!res.rows.length) {
      throw new UnauthorizedException('User not found');
    }
    const r = res.rows[0];
    return {
      id: r.id,
      name: r.full_name,
      email: r.email,
      role: r.role,
      department: r.department,
      designation: r.designation,
      phone: r.phone,
      avatarUrl: r.avatar_url,
    };
  }

  async updateAvatar(userId: string, avatarUrl: string | null) {
    const res = await this.db.query(
      `UPDATE users SET avatar_url = $1 WHERE id = $2 RETURNING id, email, full_name, role, department, designation, phone, avatar_url`,
      [avatarUrl, userId],
    );
    if (!res.rows.length) {
      throw new UnauthorizedException('User not found');
    }
    const r = res.rows[0];
    return {
      id: r.id,
      name: r.full_name,
      email: r.email,
      role: r.role,
      department: r.department,
      designation: r.designation,
      phone: r.phone,
      avatarUrl: r.avatar_url,
    };
  }

  async changePassword(userId: string, currentPass?: string, newPass?: string) {
    if (!newPass || newPass.length < 6) {
      throw new BadRequestException('New password must be at least 6 characters');
    }

    const res = await this.db.query('SELECT password_hash FROM users WHERE id = $1', [userId]);
    if (!res.rows.length) {
      throw new UnauthorizedException('User not found');
    }

    const isMatch = await bcrypt.compare(currentPass || '', res.rows[0].password_hash);
    if (!isMatch) {
      throw new BadRequestException('Current password does not match');
    }

    const newHash = await bcrypt.hash(newPass, 10);
    await this.db.query(
      'UPDATE users SET password_hash = $1, updated_at = clock_timestamp() WHERE id = $2',
      [newHash, userId],
    );

    return { success: true, message: 'Password updated successfully' };
  }
}
