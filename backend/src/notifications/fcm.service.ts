import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { initializeApp, cert, getApps } from 'firebase-admin/app';
import { getMessaging, MulticastMessage } from 'firebase-admin/messaging';
import * as fs from 'fs';
import * as path from 'path';
import { DatabaseService } from '../database/database.service';

@Injectable()
export class FcmService implements OnModuleInit {
  private readonly logger = new Logger(FcmService.name);
  private initialized = false;

  constructor(private readonly db: DatabaseService) {}

  onModuleInit() {
    this.initFirebase();
  }

  private initFirebase() {
    if (getApps().length > 0) {
      this.initialized = true;
      return;
    }

    try {
      const candidates = [
        process.env.FIREBASE_SERVICE_ACCOUNT_PATH,
        path.join(process.cwd(), 'firebase-service-account.json'),
        path.join(__dirname, '..', '..', 'firebase-service-account.json'),
        '/app/firebase-service-account.json',
      ].filter(Boolean) as string[];

      let foundPath: string | null = null;
      for (const p of candidates) {
        if (fs.existsSync(p)) {
          foundPath = p;
          break;
        }
      }

      if (foundPath) {
        const serviceAccount = JSON.parse(fs.readFileSync(foundPath, 'utf8'));
        initializeApp({
          credential: cert(serviceAccount),
          projectId: serviceAccount.project_id || 'geospatial-f4fa1',
        });
        this.initialized = true;
        this.logger.log(`Firebase Admin initialized successfully from ${foundPath}`);
      } else if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
        const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
        initializeApp({
          credential: cert(serviceAccount),
          projectId: serviceAccount.project_id || 'geospatial-f4fa1',
        });
        this.initialized = true;
        this.logger.log('Firebase Admin initialized successfully from FIREBASE_SERVICE_ACCOUNT_JSON env');
      } else {
        this.logger.warn('Firebase service account credentials not found. FCM push disabled.');
      }
    } catch (error) {
      this.logger.error('Failed to initialize Firebase Admin SDK', error);
    }
  }

  async saveToken(userId: string, token: string, deviceInfo?: string) {
    try {
      await this.db.query(
        `INSERT INTO user_fcm_tokens (user_id, token, device_info, updated_at)
         VALUES ($1, $2, $3, NOW())
         ON CONFLICT (token) DO UPDATE
         SET user_id = EXCLUDED.user_id,
             device_info = EXCLUDED.device_info,
             updated_at = NOW()`,
        [userId, token, deviceInfo || 'Android'],
      );
      this.logger.log(`Registered FCM token for user ${userId}`);
      return { success: true };
    } catch (e) {
      this.logger.error(`Error saving FCM token for user ${userId}`, e);
      throw e;
    }
  }

  async removeToken(token: string) {
    try {
      await this.db.query(`DELETE FROM user_fcm_tokens WHERE token = $1`, [token]);
    } catch (e) {
      this.logger.warn(`Could not delete invalid FCM token:`, e);
    }
  }

  async sendPushToUser(
    userId: string,
    title: string,
    body: string,
    data: Record<string, string> = {},
  ) {
    if (!this.initialized) {
      this.logger.warn('FCM not initialized, skipping push to user.');
      return;
    }

    try {
      const res = await this.db.query(
        `SELECT token FROM user_fcm_tokens WHERE user_id = $1`,
        [userId],
      );

      const tokens = res.rows.map((r) => r.token).filter(Boolean);
      if (tokens.length === 0) {
        this.logger.debug(`No FCM tokens found for user ${userId}`);
        return;
      }

      await this.sendMulticast(tokens, title, body, data);
    } catch (e) {
      this.logger.error(`Failed to send push to user ${userId}`, e);
    }
  }

  async sendPushToAdmins(
    title: string,
    body: string,
    data: Record<string, string> = {},
  ) {
    if (!this.initialized) {
      this.logger.warn('FCM not initialized, skipping push to admins.');
      return;
    }

    try {
      const res = await this.db.query(
        `SELECT DISTINCT t.token 
         FROM user_fcm_tokens t
         JOIN users u ON u.id = t.user_id
         WHERE u.role IN ('main_admin', 'finance')`,
      );

      const tokens = res.rows.map((r) => r.token).filter(Boolean);
      if (tokens.length === 0) {
        this.logger.debug('No admin FCM tokens found.');
        return;
      }

      await this.sendMulticast(tokens, title, body, data);
    } catch (e) {
      this.logger.error('Failed to send push to admins', e);
    }
  }

  private async sendMulticast(
    tokens: string[],
    title: string,
    body: string,
    data: Record<string, string> = {},
  ) {
    const stringData: Record<string, string> = {};
    for (const [key, val] of Object.entries(data)) {
      stringData[key] = String(val ?? '');
    }
    stringData.title = title;
    stringData.body = body;

    const uniqueTokens = Array.from(new Set(tokens.filter(Boolean)));
    if (uniqueTokens.length === 0) return;

    const notifType = (stringData.type || '').toLowerCase();
    const channelId = notifType.includes('attendance')
      ? 'attendance_channel'
      : notifType.includes('expense')
        ? 'expenses_channel'
        : 'general_channel';

    const notifTag = stringData.notificationId || stringData.expenseId || stringData.type || undefined;

    const message: MulticastMessage = {
      tokens: uniqueTokens,
      notification: {
        title,
        body,
      },
      data: stringData,
      android: {
        priority: 'high',
        notification: {
          channelId,
          sound: 'default',
          priority: 'max',
          defaultVibrateTimings: true,
          defaultSound: true,
          tag: notifTag,
        },
      },
    };

    try {
      const messaging = getMessaging();
      const response = await messaging.sendEachForMulticast(message);
      this.logger.log(
        `FCM multicast sent to ${tokens.length} devices: ${response.successCount} succeeded, ${response.failureCount} failed`,
      );

      if (response.failureCount > 0) {
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            const errCode = resp.error?.code;
            this.logger.warn(`FCM delivery failed for token ${tokens[idx]}: ${errCode}`);
            if (
              errCode === 'messaging/registration-token-not-registered' ||
              errCode === 'messaging/invalid-registration-token'
            ) {
              this.removeToken(tokens[idx]);
            }
          }
        });
      }
    } catch (err) {
      this.logger.error('Error in sendEachForMulticast:', err);
    }
  }
}
