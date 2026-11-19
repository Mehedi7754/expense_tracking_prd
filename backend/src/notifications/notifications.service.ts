import { Injectable, Logger } from '@nestjs/common';
import { Subject, Observable, interval, merge } from 'rxjs';
import { map, filter } from 'rxjs/operators';
import { DatabaseService } from '../database/database.service';
import { FcmService } from './fcm.service';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);
  private readonly notificationSubject = new Subject<{ data: any }>();

  constructor(
    private readonly db: DatabaseService,
    private readonly fcm: FcmService,
  ) {}

  getNotificationStream(userId: string): Observable<{ data: any }> {
    const keepAlive$ = interval(25000).pipe(
      map(() => ({ data: { type: 'ping' } }))
    );

    return new Observable<{ data: any }>((subscriber) => {
      let isPrivileged = false;
      this.db.query('SELECT role FROM users WHERE id = $1', [userId])
        .then((res) => {
          const role = (res.rows[0]?.role || '').toLowerCase().trim();
          isPrivileged =
            ['main_admin', 'admin', 'finance', 'project_manager', 'super_admin'].includes(role) ||
            role.includes('admin') ||
            role.includes('manager');
        })
        .catch((err) => {
          this.logger.error('Error fetching role in notification stream:', err);
        });

      const subscription = merge(
        this.notificationSubject.asObservable().pipe(
          filter((msg) => {
            if (!msg.data || msg.data.type === 'ping') return true;
            // Personal/direct notifications (like task assignments, chat, personal alerts):
            // Strictly delivered ONLY to the recipient user!
            if (msg.data.userId) {
              return msg.data.userId === userId;
            }
            // Broadcast notifications with no specific user_id: privileged users only, except rejected expense notices
            if (msg.data.type === 'expense_rejected') {
              return false;
            }
            return isPrivileged;
          }),
        ),
        keepAlive$,
      ).subscribe(subscriber);

      return () => subscription.unsubscribe();
    });
  }

  async findAll(userId: string) {
    const userRes = await this.db.query(
      `SELECT role FROM users WHERE id = $1`,
      [userId],
    );
    const role = (userRes.rows[0]?.role || '').toLowerCase().trim();
    const isPrivileged =
      ['main_admin', 'admin', 'finance', 'project_manager', 'super_admin'].includes(role) ||
      role.includes('admin') ||
      role.includes('manager');

    // User-targeted notifications belong strictly to that user!
    // Broadcast notifications (user_id IS NULL) are only included if the user has a privileged role (admin/manager/finance).
    // Privileged admins should NOT receive or see 'expense_rejected' notifications (only the claimant sees them) unless the admin is themselves the claimant.
    const res = await this.db.query(
      isPrivileged
        ? `SELECT n.*, 
                  COALESCE(u_actor.full_name, n.actor_name) AS resolved_actor_name, 
                  COALESCE(u_actor.avatar_url, n.actor_avatar_url) AS resolved_actor_avatar_url
           FROM notifications n
           LEFT JOIN users u_actor ON n.actor_id = u_actor.id
           WHERE (n.user_id = $1 OR (n.user_id IS NULL AND n.type != 'expense_rejected'))
             AND NOT (n.type = 'expense_rejected' AND n.actor_id = $1)
           ORDER BY n.created_at DESC LIMIT 500`
        : `SELECT n.*, 
                  COALESCE(u_actor.full_name, n.actor_name) AS resolved_actor_name, 
                  COALESCE(u_actor.avatar_url, n.actor_avatar_url) AS resolved_actor_avatar_url
           FROM notifications n
           LEFT JOIN users u_actor ON n.actor_id = u_actor.id
           WHERE n.user_id = $1
           ORDER BY n.created_at DESC LIMIT 500`,
      [userId],
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
      relatedLeaveId: r.related_leave_id,
      relatedTaskId: r.related_task_id,
      expenseDate: r.expense_date || null,
      submittedDate: r.submitted_date || null,
    }));
  }

  async create(data: {
    userId?: string | null;
    title: string;
    message: string;
    fullExplanation?: string;
    rejectionReason?: string;
    type?: string;
    relatedProjectId?: string;
    relatedExpenseId?: string;
    relatedLeaveId?: string;
    relatedTaskId?: string;
    actorId?: string;
    actorName?: string;
    actorAvatarUrl?: string;
    expenseDate?: string;
    submittedDate?: string;
    attendanceDate?: string;
  }) {
    let savedNotification: any = null;
    try {
      const res = await this.db.query(
        `INSERT INTO notifications (user_id, title, message, full_explanation, type, related_project_id, related_expense_id, related_leave_id, actor_id, actor_name, actor_avatar_url, related_task_id, expense_date, submitted_date)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
         RETURNING *`,
        [
          data.userId || null,
          data.title,
          data.message,
          data.fullExplanation || data.message,
          data.type || 'general',
          data.relatedProjectId || null,
          data.relatedExpenseId || null,
          data.relatedLeaveId || null,
          data.actorId || null,
          data.actorName || null,
          data.actorAvatarUrl || null,
          data.relatedTaskId || null,
          data.expenseDate || null,
          data.submittedDate || null,
        ],
      );
      savedNotification = res.rows[0];
    } catch (dbErr) {
      try {
        const fallbackRes = await this.db.query(
          `INSERT INTO notifications (user_id, title, message, full_explanation, type, related_project_id, related_expense_id, related_leave_id, actor_id, actor_name, actor_avatar_url, related_task_id)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
           RETURNING *`,
          [
            data.userId || null,
            data.title,
            data.message,
            data.fullExplanation || data.message,
            data.type || 'general',
            data.relatedProjectId || null,
            data.relatedExpenseId || null,
            data.relatedLeaveId || null,
            data.actorId || null,
            data.actorName || null,
            data.actorAvatarUrl || null,
            data.relatedTaskId || null,
          ],
        );
        savedNotification = fallbackRes.rows[0];
      } catch (fallbackErr) {
        this.logger.error('Database error creating notification row:', fallbackErr);
      }
    }

    // Broadcast immediately to connected admin & web client SSE streams (0ms latency)
    if (savedNotification) {
      try {
        const item = {
          id: savedNotification.id,
          userId: savedNotification.user_id,
          actorId: savedNotification.actor_id,
          actorName: data.actorName || savedNotification.actor_name,
          actorAvatarUrl: data.actorAvatarUrl || savedNotification.actor_avatar_url,
          title: savedNotification.title,
          message: savedNotification.message,
          fullExplanation: savedNotification.full_explanation || savedNotification.message,
          type: savedNotification.type,
          isRead: false,
          createdAt: savedNotification.created_at || new Date().toISOString(),
          relatedProjectId: savedNotification.related_project_id,
          relatedExpenseId: savedNotification.related_expense_id,
          relatedLeaveId: savedNotification.related_leave_id || data.relatedLeaveId || null,
          relatedTaskId: savedNotification.related_task_id,
          expenseDate: savedNotification.expense_date || data.expenseDate || null,
          submittedDate: savedNotification.submitted_date || data.submittedDate || null,
        };
        this.notificationSubject.next({ data: item });
      } catch (broadcastErr) {
        this.logger.error('Error broadcasting notification over SSE stream:', broadcastErr);
      }
    }

    // Dispatch real-time FCM Push Notification (arrives even if app is closed)
    try {
      const payloadData: Record<string, string> = {
        type: data.type || 'general',
        notificationId: savedNotification?.id || '',
      };
      if (data.relatedExpenseId) payloadData.expenseId = data.relatedExpenseId;
      if (data.relatedLeaveId) payloadData.leaveId = data.relatedLeaveId;
      if (data.relatedProjectId) payloadData.projectId = data.relatedProjectId;
      if (data.relatedTaskId) payloadData.taskId = data.relatedTaskId;
      if (data.rejectionReason) payloadData.rejectionReason = data.rejectionReason.slice(0, 500);
      if (data.actorId) payloadData.actorId = data.actorId;
      if (data.actorName) payloadData.actorName = data.actorName;
      if (data.actorAvatarUrl) payloadData.actorAvatarUrl = data.actorAvatarUrl;
      if (data.expenseDate) payloadData.expenseDate = String(data.expenseDate);
      if (data.submittedDate) payloadData.submittedDate = String(data.submittedDate);
      if (data.attendanceDate) payloadData.attendanceDate = String(data.attendanceDate);
      if (data.type?.includes('attendance')) {
        const actor = data.actorId || data.userId || 'self';
        payloadData.tag = `attendance_${actor}_${new Date().toISOString().slice(0, 10)}`;
      }

      if (data.userId) {
        await this.fcm.sendPushToUser(data.userId, data.title, data.message, payloadData);
      } else {
        // Broadcast / system notification with no specific recipient: send to admins & finance
        await this.fcm.sendPushToAdmins(data.title, data.message, payloadData);
      }
    } catch (err) {
      this.logger.error('Error dispatching FCM push from NotificationsService', err);
    }

    return savedNotification;
  }

  async markAsRead(id: string, userId: string) {
    const userRes = await this.db.query(`SELECT role FROM users WHERE id = $1`, [userId]);
    const role = (userRes.rows[0]?.role || '').toLowerCase().trim();
    const isPrivileged =
      ['main_admin', 'admin', 'finance', 'project_manager', 'super_admin'].includes(role) ||
      role.includes('admin') ||
      role.includes('manager');

    if (isPrivileged) {
      await this.db.query('UPDATE notifications SET is_read = TRUE WHERE id = $1', [id]);
    } else {
      await this.db.query(
        'UPDATE notifications SET is_read = TRUE WHERE id = $1 AND (user_id = $2 OR user_id IS NULL)',
        [id, userId],
      );
    }
    return { success: true };
  }

  async delete(id: string, userId: string) {
    const userRes = await this.db.query(`SELECT role FROM users WHERE id = $1`, [userId]);
    const role = (userRes.rows[0]?.role || '').toLowerCase().trim();
    const isPrivileged =
      ['main_admin', 'admin', 'finance', 'project_manager', 'super_admin'].includes(role) ||
      role.includes('admin') ||
      role.includes('manager');

    if (isPrivileged) {
      await this.db.query('DELETE FROM notifications WHERE id = $1', [id]);
    } else {
      await this.db.query('DELETE FROM notifications WHERE id = $1 AND (user_id = $2 OR user_id IS NULL)', [id, userId]);
    }
    return { success: true };
  }

  async deleteAll(userId: string) {
    const userRes = await this.db.query(`SELECT role FROM users WHERE id = $1`, [userId]);
    const role = (userRes.rows[0]?.role || '').toLowerCase().trim();
    const isPrivileged =
      ['main_admin', 'admin', 'finance', 'project_manager', 'super_admin'].includes(role) ||
      role.includes('admin') ||
      role.includes('manager');

    if (isPrivileged) {
      await this.db.query('DELETE FROM notifications', []);
    } else {
      await this.db.query('DELETE FROM notifications WHERE user_id = $1', [userId]);
    }
    return { success: true };
  }
}
