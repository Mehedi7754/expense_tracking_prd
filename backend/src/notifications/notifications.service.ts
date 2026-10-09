import { Injectable, Logger } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { FcmService } from './fcm.service';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    private readonly db: DatabaseService,
    private readonly fcm: FcmService,
  ) {}

  async findAll(userId: string) {
    const userRes = await this.db.query(
      `SELECT role FROM users WHERE id = $1`,
      [userId],
    );
    const role = userRes.rows[0]?.role;
    const isPrivileged = role === 'main_admin' || role === 'finance';

    const res = await this.db.query(
      isPrivileged
        ? `SELECT n.*, 
                  COALESCE(u_actor.full_name, n.actor_name) AS resolved_actor_name, 
                  COALESCE(u_actor.avatar_url, n.actor_avatar_url) AS resolved_actor_avatar_url
           FROM notifications n
           LEFT JOIN users u_actor ON n.actor_id = u_actor.id
           ORDER BY n.created_at DESC LIMIT 100`
        : `SELECT n.*, 
                  COALESCE(u_actor.full_name, n.actor_name) AS resolved_actor_name, 
                  COALESCE(u_actor.avatar_url, n.actor_avatar_url) AS resolved_actor_avatar_url
           FROM notifications n
           LEFT JOIN users u_actor ON n.actor_id = u_actor.id
           WHERE (n.user_id = $1 OR n.user_id IS NULL) 
           ORDER BY n.created_at DESC LIMIT 100`,
      isPrivileged ? [] : [userId],
    );
    return res.rows.map((r) => ({
      id: r.id,
      userId: r.user_id,
      actorId: r.actor_id,
      actorName: r.resolved_actor_name || r.actor_name,
      actorAvatarUrl: r.resolved_actor_avatar_url || r.actor_avatar_url,
      title: r.title,
      message: r.message,
      fullExplanation: r.full_explanation || r.message,
      type: r.type,
      isRead: r.is_read,
      createdAt: r.created_at,
      relatedProjectId: r.related_project_id,
      relatedExpenseId: r.related_expense_id,
    }));
  }

  async create(data: {
    userId: string;
    title: string;
    message: string;
    fullExplanation?: string;
    type?: string;
    relatedProjectId?: string;
    relatedExpenseId?: string;
    actorId?: string;
    actorName?: string;
    actorAvatarUrl?: string;
  }) {
    const res = await this.db.query(
      `INSERT INTO notifications (user_id, title, message, full_explanation, type, related_project_id, related_expense_id, actor_id, actor_name, actor_avatar_url)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
       RETURNING *`,
      [
        data.userId,
        data.title,
        data.message,
        data.fullExplanation || data.message,
        data.type || 'general',
        data.relatedProjectId || null,
        data.relatedExpenseId || null,
        data.actorId || null,
        data.actorName || null,
        data.actorAvatarUrl || null,
      ],
    );

    // Dispatch real-time FCM Push Notification (arrives even if app is closed)
    try {
      const payloadData: Record<string, string> = {
        type: data.type || 'general',
        notificationId: res.rows[0]?.id || '',
      };
      if (data.relatedExpenseId) payloadData.expenseId = data.relatedExpenseId;
      if (data.relatedProjectId) payloadData.projectId = data.relatedProjectId;
      if (data.actorId) payloadData.actorId = data.actorId;
      if (data.actorName) payloadData.actorName = data.actorName;
      if (data.actorAvatarUrl) payloadData.actorAvatarUrl = data.actorAvatarUrl;

      if (data.userId) {
        await this.fcm.sendPushToUser(data.userId, data.title, data.message, payloadData);
      } else {
        // Broadcast / system notification with no specific recipient: send to admins & finance
        await this.fcm.sendPushToAdmins(data.title, data.message, payloadData);
      }
    } catch (err) {
      this.logger.error('Error dispatching FCM push from NotificationsService', err);
    }

    return res.rows[0];
  }

  async markAsRead(id: string, userId: string) {
    await this.db.query(
      'UPDATE notifications SET is_read = TRUE WHERE id = $1 AND user_id = $2',
      [id, userId],
    );
    return { success: true };
  }

  async delete(id: string, userId: string) {
    await this.db.query(
      'DELETE FROM notifications WHERE id = $1 AND user_id = $2',
      [id, userId],
    );
    return { success: true };
  }

  async deleteAll(userId: string) {
    await this.db.query(
      'DELETE FROM notifications WHERE user_id = $1',
      [userId],
    );
    return { success: true };
  }
}
