import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';

@Injectable()
export class UsersService {
  constructor(private readonly db: DatabaseService) {}

  async findAll(query?: string) {
    let sql = `
      SELECT id, email, full_name, role, department, designation, phone, avatar_url, is_active
      FROM users
      WHERE is_active = TRUE
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
       WHERE email = $1 AND is_active = TRUE`,
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
}
