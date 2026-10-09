import { Injectable, Logger, NotFoundException, BadRequestException } from '@nestjs/common';
import { Subject, Observable } from 'rxjs';
import { DatabaseService } from '../database/database.service';
import { FcmService } from '../notifications/fcm.service';
import { UploadsService } from '../uploads/uploads.service';

export interface ChatChannelSummary {
  id: string;
  type: 'direct' | 'project';
  name?: string;
  projectId?: string;
  projectName?: string;
  projectCode?: string;
  projectStatus?: string;
  projectImageUrl?: string;
  otherUser?: {
    id: string;
    fullName: string;
    avatarUrl?: string;
    role: string;
    department?: string;
  };
  lastMessage?: {
    id: string;
    content: string;
    imageUrl?: string;
    senderId: string;
    senderName: string;
    createdAt: string;
    projectId?: string;
  };
  unreadCount: number;
  updatedAt: string;
}

@Injectable()
export class ChatService {
  private readonly logger = new Logger(ChatService.name);
  private readonly channelStreams = new Map<string, Subject<{ data: any }>>();

  constructor(
    private readonly db: DatabaseService,
    private readonly fcm: FcmService,
    private readonly uploads: UploadsService,
  ) {}

  getChannelStream(channelId: string): Observable<{ data: any }> {
    if (!this.channelStreams.has(channelId)) {
      this.channelStreams.set(channelId, new Subject<{ data: any }>());
    }
    return this.channelStreams.get(channelId)!.asObservable();
  }

  private broadcastToChannel(channelId: string, message: any) {
    const stream = this.channelStreams.get(channelId);
    if (stream) {
      stream.next({ data: message });
    }
  }

  /**
   * Automatically ensure project channels exist for all assigned projects.
   */
  private async ensureUserProjectChannels(userId: string): Promise<void> {
    try {
      const userRes = await this.db.query(`SELECT role FROM users WHERE id = $1`, [userId]);
      if (userRes.rows.length === 0) return;
      const role = userRes.rows[0].role;
      const isAdminOrManager = role === 'main_admin' || role === 'project_manager' || role === 'finance';

      const projQuery = isAdminOrManager
        ? `SELECT p.id, p.name, p.project_code, p.created_by FROM projects p WHERE p.is_closed = FALSE`
        : `SELECT p.id, p.name, p.project_code, p.created_by FROM projects p 
           WHERE p.is_closed = FALSE 
             AND (p.created_by = $1 OR p.id IN (SELECT project_id FROM project_members WHERE user_id = $1))`;

      const projects = await this.db.query(projQuery, isAdminOrManager ? [] : [userId]);

      for (const proj of projects.rows) {
        const existing = await this.db.query(
          `SELECT id FROM chat_channels WHERE type = 'project' AND project_id = $1 LIMIT 1`,
          [proj.id],
        );
        let channelId: string;
        if (existing.rows.length > 0) {
          channelId = existing.rows[0].id;
        } else {
          const newChan = await this.db.query(
            `INSERT INTO chat_channels (type, name, project_id, created_by)
             VALUES ('project', $1, $2, $3)
             RETURNING id`,
            [proj.name, proj.id, proj.created_by || userId],
          );
          channelId = newChan.rows[0].id;
        }

        await this.db.query(
          `INSERT INTO chat_participants (channel_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
          [channelId, userId],
        );
      }
    } catch (e) {
      this.logger.error('Error in ensureUserProjectChannels', e);
    }
  }

  /**
   * Get all conversation channels for the given user with unread counts and last message.
   */
  async getUserChannels(userId: string): Promise<ChatChannelSummary[]> {
    await this.ensureUserProjectChannels(userId);
    const query = `
      SELECT 
        c.id,
        c.type,
        c.name,
        c.project_id,
        c.updated_at,
        p.name AS project_name,
        p.project_code AS project_code,
        p.status AS project_status,
        p.image_url AS project_image_url,
        cp.last_read_at,
        (
          SELECT COUNT(*)
          FROM chat_messages cm_sub
          WHERE cm_sub.channel_id = c.id
            AND cm_sub.created_at > cp.last_read_at
            AND cm_sub.sender_id != $1
        )::int AS unread_count,
        lm.id AS last_msg_id,
        lm.content AS last_msg_content,
        lm.image_url AS last_msg_image_url,
        lm.project_id AS last_msg_project_id,
        lm.created_at AS last_msg_created_at,
        lm.sender_id AS last_msg_sender_id,
        u_lm.full_name AS last_msg_sender_name,
        other_u.id AS other_user_id,
        other_u.full_name AS other_user_name,
        other_u.avatar_url AS other_user_avatar,
        other_u.role AS other_user_role,
        other_u.department AS other_user_dept
      FROM chat_participants cp
      JOIN chat_channels c ON c.id = cp.channel_id
      LEFT JOIN projects p ON p.id = c.project_id
      LEFT JOIN LATERAL (
        SELECT cm.id, cm.content, cm.image_url, cm.project_id, cm.created_at, cm.sender_id
        FROM chat_messages cm
        WHERE cm.channel_id = c.id
        ORDER BY cm.created_at DESC
        LIMIT 1
      ) lm ON TRUE
      LEFT JOIN users u_lm ON u_lm.id = lm.sender_id
      LEFT JOIN LATERAL (
        SELECT u2.id, u2.full_name, u2.avatar_url, u2.role, u2.department
        FROM chat_participants cp2
        JOIN users u2 ON u2.id = cp2.user_id
        WHERE cp2.channel_id = c.id AND cp2.user_id != $1
        LIMIT 1
      ) other_u ON c.type = 'direct'
      WHERE cp.user_id = $1
      ORDER BY c.updated_at DESC;
    `;

    const res = await this.db.query(query, [userId]);

    return res.rows.map((r) => {
      const summary: ChatChannelSummary = {
        id: r.id,
        type: r.type,
        name: r.name,
        projectId: r.project_id,
        projectName: r.project_name,
        projectCode: r.project_code,
        projectStatus: r.project_status,
        projectImageUrl: r.project_image_url,
        unreadCount: Number(r.unread_count || 0),
        updatedAt: r.updated_at,
      };

      if (r.type === 'direct' && r.other_user_id) {
        summary.otherUser = {
          id: r.other_user_id,
          fullName: r.other_user_name || 'User',
          avatarUrl: r.other_user_avatar,
          role: r.other_user_role,
          department: r.other_user_dept,
        };
      }

      if (r.last_msg_id) {
        summary.lastMessage = {
          id: r.last_msg_id,
          content: r.last_msg_content,
          imageUrl: r.last_msg_image_url,
          senderId: r.last_msg_sender_id,
          senderName: r.last_msg_sender_name || 'Colleague',
          createdAt: r.last_msg_created_at,
          projectId: r.last_msg_project_id,
        };
      }

      return summary;
    });
  }

  /**
   * Get or create a direct 1-on-1 chat channel between two users.
   */
  async getOrCreateDirectChannel(currentUserId: string, recipientId: string) {
    if (currentUserId === recipientId) {
      throw new BadRequestException('Cannot start a chat with yourself');
    }

    const recRes = await this.db.query(`SELECT id, full_name, avatar_url, role, department FROM users WHERE id = $1`, [recipientId]);
    if (recRes.rows.length === 0) {
      throw new NotFoundException('Recipient user not found');
    }
    const recipient = recRes.rows[0];

    const existing = await this.db.query(
      `
      SELECT c.id 
      FROM chat_channels c
      JOIN chat_participants p1 ON p1.channel_id = c.id AND p1.user_id = $1
      JOIN chat_participants p2 ON p2.channel_id = c.id AND p2.user_id = $2
      WHERE c.type = 'direct'
      LIMIT 1
      `,
      [currentUserId, recipientId],
    );

    let channelId: string;
    if (existing.rows.length > 0) {
      channelId = existing.rows[0].id;
    } else {
      const newChan = await this.db.query(
        `INSERT INTO chat_channels (type, created_by) VALUES ('direct', $1) RETURNING id`,
        [currentUserId],
      );
      channelId = newChan.rows[0].id;

      await this.db.query(
        `INSERT INTO chat_participants (channel_id, user_id) VALUES ($1, $2), ($1, $3) ON CONFLICT DO NOTHING`,
        [channelId, currentUserId, recipientId],
      );
    }

    return {
      channelId,
      type: 'direct',
      otherUser: {
        id: recipient.id,
        fullName: recipient.full_name,
        avatarUrl: recipient.avatar_url,
        role: recipient.role,
        department: recipient.department,
      },
    };
  }

  /**
   * Get or create a group channel for a project.
   */
  async getOrCreateProjectChannel(currentUserId: string, projectId: string) {
    const pRes = await this.db.query(`SELECT id, name, project_code, status, created_by, image_url FROM projects WHERE id = $1`, [projectId]);
    if (pRes.rows.length === 0) {
      throw new NotFoundException('Project not found');
    }
    const project = pRes.rows[0];

    const existing = await this.db.query(
      `SELECT id FROM chat_channels WHERE type = 'project' AND project_id = $1 LIMIT 1`,
      [projectId],
    );

    let channelId: string;
    if (existing.rows.length > 0) {
      channelId = existing.rows[0].id;
      await this.db.query(
        `INSERT INTO chat_participants (channel_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
        [channelId, currentUserId],
      );
    } else {
      const newChan = await this.db.query(
        `INSERT INTO chat_channels (type, name, project_id, created_by) VALUES ('project', $1, $2, $3) RETURNING id`,
        [project.name, projectId, currentUserId],
      );
      channelId = newChan.rows[0].id;

      await this.db.query(
        `
        INSERT INTO chat_participants (channel_id, user_id)
        SELECT $1, u.id
        FROM users u
        WHERE u.id = $2 
           OR u.id = $3
           OR u.role = 'main_admin'
           OR u.id IN (SELECT user_id FROM project_members WHERE project_id = $4)
        ON CONFLICT DO NOTHING
        `,
        [channelId, currentUserId, project.created_by, projectId],
      );
    }

    return {
      channelId,
      type: 'project',
      projectId: project.id,
      projectName: project.name,
      projectCode: project.project_code,
      projectStatus: project.status,
      projectImageUrl: project.image_url,
    };
  }

  /**
   * Get messages for a channel. Auto marks as read for current user.
   */
  async getChannelMessages(channelId: string, userId: string, limit = 50) {
    const partCheck = await this.db.query(
      `SELECT id FROM chat_participants WHERE channel_id = $1 AND user_id = $2`,
      [channelId, userId],
    );
    if (partCheck.rows.length === 0) {
      const chanRes = await this.db.query(`SELECT type, project_id FROM chat_channels WHERE id = $1`, [channelId]);
      if (chanRes.rows.length === 0) {
        throw new NotFoundException('Channel not found');
      }
      await this.db.query(
        `INSERT INTO chat_participants (channel_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
        [channelId, userId],
      );
    }

    await this.db.query(
      `UPDATE chat_participants SET last_read_at = NOW() WHERE channel_id = $1 AND user_id = $2`,
      [channelId, userId],
    );

    const msgQuery = `
      SELECT 
        m.id,
        m.channel_id,
        m.sender_id,
        m.content,
        m.image_url,
        m.project_id,
        m.reply_to_id,
        m.created_at,
        u.full_name AS sender_name,
        u.avatar_url AS sender_avatar_url,
        u.role AS sender_role,
        p.name AS project_name,
        p.project_code AS project_code,
        p.status AS project_status,
        p.budget AS project_budget,
        p.image_url AS project_image_url,
        (SELECT COALESCE(SUM(e.amount), 0) FROM expenses e WHERE e.project_id = p.id AND e.status = 'approved') AS project_spent
      FROM chat_messages m
      JOIN users u ON u.id = m.sender_id
      LEFT JOIN projects p ON p.id = m.project_id
      WHERE m.channel_id = $1
      ORDER BY m.created_at ASC
      LIMIT $2;
    `;

    const res = await this.db.query(msgQuery, [channelId, limit]);

    return res.rows.map((r) => ({
      id: r.id,
      channelId: r.channel_id,
      senderId: r.sender_id,
      senderName: r.sender_name,
      senderAvatarUrl: r.sender_avatar_url,
      senderRole: r.sender_role,
      content: r.content,
      imageUrl: r.image_url,
      projectId: r.project_id,
      projectName: r.project_name,
      projectCode: r.project_code,
      projectStatus: r.project_status,
      projectBudget: r.project_budget ? Number(r.project_budget) : undefined,
      projectSpent: r.project_spent ? Number(r.project_spent) : undefined,
      projectImageUrl: r.project_image_url,
      replyToId: r.reply_to_id,
      createdAt: r.created_at,
      isMe: r.sender_id === userId,
    }));
  }

  /**
   * Send a new message to a channel.
   * Dispatches FCM push notification directly to other participants WITHOUT writing to notifications table.
   */
  async sendMessage(
    userId: string,
    channelId: string,
    content: string,
    imageUrl?: string,
    projectId?: string,
  ) {
    if ((!content || content.trim().length === 0) && !imageUrl && !projectId) {
      throw new BadRequestException('Message cannot be empty');
    }

    const chanRes = await this.db.query(
      `SELECT c.id, c.type, c.name, c.project_id, p.name AS project_name 
       FROM chat_channels c 
       LEFT JOIN projects p ON p.id = c.project_id
       WHERE c.id = $1`,
      [channelId],
    );
    if (chanRes.rows.length === 0) {
      throw new NotFoundException('Channel not found');
    }
    const channel = chanRes.rows[0];

    await this.db.query(
      `INSERT INTO chat_participants (channel_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
      [channelId, userId],
    );

    const insRes = await this.db.query(
      `
      INSERT INTO chat_messages (channel_id, sender_id, content, image_url, project_id)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING *
      `,
      [channelId, userId, content ? content.trim() : '', imageUrl || null, projectId || null],
    );
    const msg = insRes.rows[0];

    await this.db.query(
      `UPDATE chat_channels SET updated_at = NOW() WHERE id = $1`,
      [channelId],
    );
    await this.db.query(
      `UPDATE chat_participants SET last_read_at = NOW() WHERE channel_id = $1 AND user_id = $2`,
      [channelId, userId],
    );

    const senderRes = await this.db.query(
      `SELECT full_name, avatar_url, role FROM users WHERE id = $1`,
      [userId],
    );
    const sender = senderRes.rows[0] || { full_name: 'Colleague', avatar_url: null, role: 'member' };

    let mentionedProj: any = null;
    if (projectId) {
      const pRes = await this.db.query(
        `SELECT name, project_code, status, budget, image_url, (SELECT COALESCE(SUM(amount), 0) FROM expenses WHERE project_id = projects.id AND status = 'approved') AS spent FROM projects WHERE id = $1`,
        [projectId],
      );
      if (pRes.rows.length > 0) mentionedProj = pRes.rows[0];
    }

    const fullMessage = {
      id: msg.id,
      channelId: msg.channel_id,
      senderId: msg.sender_id,
      senderName: sender.full_name,
      senderAvatarUrl: sender.avatar_url,
      senderRole: sender.role,
      content: msg.content,
      imageUrl: msg.image_url,
      projectId: msg.project_id,
      projectName: mentionedProj?.name,
      projectCode: mentionedProj?.project_code,
      projectStatus: mentionedProj?.status,
      projectBudget: mentionedProj?.budget ? Number(mentionedProj.budget) : undefined,
      projectSpent: mentionedProj?.spent ? Number(mentionedProj.spent) : undefined,
      projectImageUrl: mentionedProj?.image_url,
      replyToId: msg.reply_to_id,
      createdAt: msg.created_at,
      isMe: true,
    };

    this.dispatchPushToParticipants(channel, sender, fullMessage, userId).catch((err) => {
      this.logger.error('Failed to dispatch chat push notification', err);
    });

    this.broadcastToChannel(channelId, fullMessage);

    return fullMessage;
  }

  private async dispatchPushToParticipants(
    channel: any,
    sender: any,
    message: any,
    senderId: string,
  ) {
    try {
      const parts = await this.db.query(
        `SELECT user_id FROM chat_participants WHERE channel_id = $1 AND user_id != $2`,
        [channel.id, senderId],
      );

      if (parts.rows.length === 0) return;

      const title = channel.type === 'project'
        ? `${sender.full_name} (${channel.project_name || channel.name || 'Project'})`
        : sender.full_name;

      const bodyText = message.imageUrl && (!message.content || message.content.length === 0)
        ? '📷 Sent a photo'
        : message.content || 'New message';

      const payload: Record<string, string> = {
        type: 'chat',
        channelId: channel.id,
        messageId: message.id,
        senderId: senderId,
        senderName: sender.full_name,
        preview: bodyText,
      };

      if (sender.avatar_url) payload.senderAvatarUrl = sender.avatar_url;
      if (channel.project_id) payload.projectId = channel.project_id;

      for (const p of parts.rows) {
        await this.fcm.sendPushToUser(p.user_id, title, bodyText, payload);
      }
    } catch (e) {
      this.logger.error('Error dispatching chat push notifications', e);
    }
  }

  async markChannelAsRead(channelId: string, userId: string) {
    await this.db.query(
      `UPDATE chat_participants SET last_read_at = NOW() WHERE channel_id = $1 AND user_id = $2`,
      [channelId, userId],
    );
    return { success: true };
  }

  async getTotalUnreadCount(userId: string): Promise<number> {
    const res = await this.db.query(
      `
      SELECT COUNT(*)::int AS total
      FROM chat_messages cm
      JOIN chat_participants cp ON cp.channel_id = cm.channel_id AND cp.user_id = $1
      WHERE cm.created_at > cp.last_read_at
        AND cm.sender_id != $1
      `,
      [userId],
    );
    return Number(res.rows[0]?.total || 0);
  }

  async uploadChatPhoto(base64Data: string) {
    return this.uploads.saveFile(base64Data, 'chat');
  }
}
