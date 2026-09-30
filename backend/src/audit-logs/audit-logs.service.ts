import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';

@Injectable()
export class AuditLogsService {
  constructor(private readonly db: DatabaseService) {}

  async findAll(limit = 100) {
    const res = await this.db.query(
      `SELECT a.*, u.full_name as user_name, u.role as user_role
       FROM audit_logs a
       LEFT JOIN users u ON u.id = a.user_id
       ORDER BY a.created_at DESC
       LIMIT $1`,
      [limit],
    );

    return res.rows.map((r) => ({
      id: r.id,
      userId: r.user_id,
      userName: r.user_name || 'System',
      userRole: r.user_role || 'System',
      action: r.action,
      entityType: r.entity_type,
      entityId: r.entity_id,
      details: r.details,
      timestamp: r.created_at,
    }));
  }

  async log(data: any, user?: any) {
    const userId = user?.id || data.userId || null;
    const userName = user?.name || user?.full_name || data.userName || 'System Admin';
    const userRole = user?.role || data.userRole || 'main_admin';

    const res = await this.db.query(
      `INSERT INTO audit_logs (user_id, user_name, user_role, action, entity_type, entity_id, details)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [
        userId,
        userName,
        userRole,
        data.action,
        data.entityType || data.entity_type || 'General',
        data.entityId || data.entity_id || 'system',
        typeof data.details === 'string' ? data.details : JSON.stringify(data.details || {}),
      ],
    );
    return res.rows[0];
  }
}
