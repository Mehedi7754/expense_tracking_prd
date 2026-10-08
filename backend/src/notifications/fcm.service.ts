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
        const defaultSa = {
          type: "service_account",
          project_id: "geospatial-f4fa1",
          private_key_id: "9ac42be605ffb648729eafb92dd87f33d0640241",
          private_key: "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDaKpvn1w712cYh\n2XBSulk+++orT+TIlQzF+F2J5jyNjuYIcs3wmfrYlygYFqdMq08NjdNvN6y6JQ2Q\n7492qrUrgBgk7dftqQEu0U1t3zMW0ENtRjSzx8ZtjOKgOAFw2D3rwcMkEILd3dil\nhD0J93BS0KicdS/rlWvDPe7UysOWMpFg3xsKUY+Igxn9vXm7j8UfPgFUJDqz6+Zp\ng1GeA/Tegg3MNMtqtH4bBGgmIDGc/W0MiuMApP1QIopNaNI5n5aiQkdw/ppJww2y\nv1x80kv/ZXxw7Ej9AeumRM923A62ztoXdwh0XJFuPrjJEhpdC5UK3fDuIXY4mYMS\nUz8rTTWnAgMBAAECggEAE/d+WVOXbOzHc2WhIBEqBdescNZZC/qINr4qYWqO9C21\n4+QN8Q1Gpff/lWTNXvj2vTjTtwQTbN3jRfaG3Md22UpZ61dRQdEL6KsDOSEKXfYl\nlaStQh7wjCouu5ckmp1P3XnYUD6qm3+oSk22AGmDADFUnS0ke50rRa0vZI5CJEbF\nO+rrhiMLlV92KLaVMsvi8SANXgeAA3y4p/JS94xTRNINNacyobWjFlTrPrJ/JbDU\nN9kUf2RjwKePvHVnPgMsx0DmSthLHXfzv6GmzqTKbZPnb+xbPcxOJn6WQiIPWXH6\nxCTmhb3wuMbqI5R/2V7sarn86vDq92qfgMQnMwtkEQKBgQDzxm7m2rcJYcrrsLeN\n4ev6x4SFJvxPyFKr4wU1AWzWkEKfnCmDgKqaboAxSaCcLBCPOvBFA7YP0YRFRW+L\nWl8PrUGxi/5y0U6j3qyq5oHlQ/IYlBM9BXOjTfm2luGMaqAbK/0hA3UCFNyfZAl0\ncCX/Cnghag4LWFsEz7jOGs5VcwKBgQDlG2nTVy/rSYChXHEjtAjI2S0LPUCV25rC\nTrWkrw8ETohp2Ml0bzEJUdyqzIv3xRfOrktNIVhM+Em+q7v/9hx4gzqQyKKvSpHl\niRDMCWYfcH0p0vRl7obbuwaE/2DLY239Zj2cNbqjzixz8UGGAW+gAPpa9RoUY+O2\n4Y/F3Olx/QKBgDU9TDE86SayZeftk1j4U1pUwrt11TrzbCLAFP4LjqKZpQNIzsQ6\nkIfjxDl/dAVHlmJBpAHemp9/yZx7Wq4bkZFR7HwDMBIRZlRhqGI2r33Lxg7aIA1+\nqE+tEvFuqFnLW6YziDfyklZfCgQBjBMS/ylhNvVNPT37EP3PA/R3ZELDAoGBANUM\n+QwfN+CFKajkXhHliYW877ZT74tr/C5VI3VRlZVbsl87yZsNC3yvM5VhQYfXMJxy\nWHQRXhu1iF5XNSyBoVgwMHYTHbYEkkfxfj0/QEhcQwhxs/RWK/KJqTZkhY6dl9rd\nCM4K6NULFSt8XoJPM46HWkjbRLVRbqDSgPBuzmfBAoGBAJ9yHjaHUpPtpWUcLdaI\npFa8NRjpw1m4Nf92sUnOLLRaMBxhloutweHi9ZqDnFV6xn06gCXC8iC3yHajAqUM\nQ1p21Q+Z4NGvffAQGGDIs8meaMtdbF7ASr/Lux1AXd3JxT3HeeV6eNc3T6c138Sw\nDAnmE1XRRzE1H+pBpHBA/BSW\n-----END PRIVATE KEY-----\n",
          client_email: "firebase-adminsdk-fbsvc@geospatial-f4fa1.iam.gserviceaccount.com",
          client_id: "101811539567765777345",
          auth_uri: "https://accounts.google.com/o/oauth2/auth",
          token_uri: "https://oauth2.googleapis.com/token",
          auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs",
          client_x509_cert_url: "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40geospatial-f4fa1.iam.gserviceaccount.com",
          universe_domain: "googleapis.com"
        };
        initializeApp({
          credential: cert(defaultSa as any),
          projectId: 'geospatial-f4fa1',
        });
        this.initialized = true;
        this.logger.log('Firebase Admin initialized successfully with bundled fallback credentials');
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
          icon: 'launcher_icon',
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
