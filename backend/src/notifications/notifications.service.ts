import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';

@Injectable()
export class NotificationsService {
  constructor(private readonly db: DatabaseService) {}

  async findAll(userId: string) {
    const res = await this.db.query(
      `SELECT * FROM notifications
       WHERE user_id = $1
       ORDER BY created_at DESC`,
      [userId],
    );
    return res.rows.map((r) => ({
      id: r.id,
      userId: r.user_id,
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
  }) {
    const res = await this.db.query(
      `INSERT INTO notifications (user_id, title, message, full_explanation, type, related_project_id, related_expense_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [
        data.userId,
        data.title,
        data.message,
        data.fullExplanation || data.message,
        data.type || 'general',
        data.relatedProjectId || null,
        data.relatedExpenseId || null,
      ],
    );
    return res.rows[0];
  }

  async markAsRead(id: string, userId: string) {
    await this.db.query(
      'UPDATE notifications SET is_read = TRUE WHERE id = $1 AND user_id = $2',
      [id, userId],
    );
    return { success: true };
  }
}
