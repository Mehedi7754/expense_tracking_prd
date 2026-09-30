import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { DatabaseService } from '../database/database.service';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    config: ConfigService,
    private readonly db: DatabaseService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.get<string>('JWT_SECRET', 'spendwise_super_secret_jwt_key_2026_enterprise_pfis'),
    });
  }

  async validate(payload: any) {
    const res = await this.db.query(
      `SELECT u.id, u.email, u.full_name, u.role, u.department, u.designation, u.phone, u.avatar_url,
              COALESCE(ARRAY_AGG(pm.project_id) FILTER (WHERE pm.project_id IS NOT NULL), '{}') AS assigned_project_ids
       FROM users u
       LEFT JOIN project_members pm ON pm.user_id = u.id
       WHERE u.id = $1 AND u.is_active = TRUE
       GROUP BY u.id`,
      [payload.sub],
    );

    if (!res.rows.length) {
      throw new UnauthorizedException('User no longer active or exists');
    }

    const row = res.rows[0];
    return {
      id: row.id,
      email: row.email,
      name: row.full_name,
      role: row.role,
      department: row.department,
      designation: row.designation,
      phone: row.phone,
      avatarUrl: row.avatar_url,
      assignedProjectIds: row.assigned_project_ids,
    };
  }
}
