import { Injectable, UnauthorizedException, ConflictException } from '@nestjs/common';
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
    const existing = await this.db.query(
      'SELECT id FROM users WHERE email = $1',
      [dto.email.trim().toLowerCase()],
    );

    if (existing.rows.length) {
      throw new ConflictException('Email already registered');
    }

    const roleEnum = this.mapRole(dto.role);
    const passwordHash = await bcrypt.hash(dto.password, 10);

    const insertRes = await this.db.query(
      `INSERT INTO users (email, password_hash, full_name, role, department, designation, phone)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING id, email, full_name, role, department, designation, phone, avatar_url`,
      [
        dto.email.trim().toLowerCase(),
        passwordHash,
        dto.name.trim(),
        roleEnum,
        dto.department || 'Operations',
        dto.designation || '',
        dto.phone || '',
      ],
    );

    const row = insertRes.rows[0];
    const payload = { sub: row.id, email: row.email, role: row.role };
    const token = this.jwtService.sign(payload);

    const user = {
      id: row.id,
      name: row.full_name,
      email: row.email,
      role: row.role,
      department: row.department,
      designation: row.designation,
      phone: row.phone,
      avatarUrl: row.avatar_url,
      assignedProjectIds: [],
    };

    return {
      token,
      accessToken: token,
      user,
    };
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
}
