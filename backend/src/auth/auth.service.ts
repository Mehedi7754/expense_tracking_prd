import { Injectable, UnauthorizedException, ConflictException, BadRequestException, ForbiddenException, Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { EmailService } from '../email/email.service';
import { DatabaseService } from '../database/database.service';
import { NotificationsService } from '../notifications/notifications.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly db: DatabaseService,
    private readonly jwtService: JwtService,
    private readonly emailService: EmailService,
    private readonly notificationsService: NotificationsService,
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
    const identifier = dto.email.trim();
    const normalizedIdentifier = identifier.toLowerCase();
    let res = await this.db.query(
      `SELECT u.id, u.employee_code, u.email, u.password_hash, u.full_name, u.role, u.department, u.designation, u.phone, u.avatar_url, u.home_latitude, u.home_longitude, u.is_active,
              COALESCE(ARRAY_AGG(pm.project_id) FILTER (WHERE pm.project_id IS NOT NULL), '{}') AS assigned_project_ids
       FROM users u
       LEFT JOIN project_members pm ON pm.user_id = u.id
       WHERE (LOWER(u.email::text) = $1 OR LOWER(COALESCE(u.employee_code, '')) = $1)
       GROUP BY u.id`,
      [normalizedIdentifier],
    );

    if (!res.rows.length) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const userRow = res.rows[0];
    let isPasswordValid = false;
    try {
      isPasswordValid = await bcrypt.compare(dto.password, userRow.password_hash);
    } catch (_) {
      isPasswordValid = false;
    }
    
    // Allow direct comparison only if DB stored plaintext password legacy
    if (!isPasswordValid && userRow.password_hash === dto.password) {
      isPasswordValid = true;
    }

    if (!isPasswordValid) {
      throw new UnauthorizedException('Invalid credentials');
    }

    if (userRow.is_active !== true) {
      throw new UnauthorizedException(
        'Your account is pending administrator approval. Please wait for an administrator to activate your profile.',
      );
    }

    const payload = { sub: userRow.id, email: userRow.email, role: userRow.role };
    const token = this.jwtService.sign(payload);

    const user = {
      id: userRow.id,
      employeeCode: userRow.employee_code || '',
      name: userRow.full_name,
      email: userRow.email,
      role: userRow.role,
      department: userRow.department,
      designation: userRow.designation,
      phone: userRow.phone,
      avatarUrl: userRow.avatar_url,
      homeLatitude: userRow.home_latitude === null ? null : Number(userRow.home_latitude),
      homeLongitude: userRow.home_longitude === null ? null : Number(userRow.home_longitude),
      assignedProjectIds: userRow.assigned_project_ids,
    };

    // Non-blocking security audit email to active system admins
    this.sendLoginAlertToAdmins(userRow.id, userRow.full_name, userRow.email, userRow.role);

    return {
      token,
      accessToken: token,
      user,
    };
  }

  async register(dto: RegisterDto) {
    const cleanEmail = dto.email.trim().toLowerCase();
    const cleanName = dto.name.trim();

    if (!cleanName) {
      throw new BadRequestException('Full name is required.');
    }
    if (!cleanEmail || !cleanEmail.includes('@')) {
      throw new BadRequestException('A valid email address is required.');
    }
    if (!dto.password || dto.password.length < 3) {
      throw new BadRequestException('Password must be at least 3 characters long.');
    }

    // Check if email is already taken
    const existing = await this.db.query(
      `SELECT id FROM users WHERE LOWER(email) = $1 LIMIT 1`,
      [cleanEmail],
    );
    if (existing.rows.length) {
      throw new ConflictException('An account with this email address already exists.');
    }

    const passwordHash = await bcrypt.hash(dto.password, 10);
    const department = (dto.department || '').trim() || 'General';
    const designation = (dto.designation || '').trim() || 'Employee';
    const phone = (dto.phone || '').trim() || null;

    // Strict security: Role is ALWAYS forced to 'project_member' and is_active is ALWAYS FALSE
    const insertRes = await this.db.query(
      `INSERT INTO users (email, password_hash, full_name, role, department, designation, phone, is_active, created_at, updated_at)
       VALUES ($1, $2, $3, 'project_member', $4, $5, $6, FALSE, NOW(), NOW())
       RETURNING id, email, full_name, role, department, designation, phone, is_active`,
      [cleanEmail, passwordHash, cleanName, department, designation, phone],
    );

    const newUser = insertRes.rows[0];

    // 1. Create In-App Notification & Broadcast Push to all Admins
    try {
      await this.notificationsService.create({
        userId: null, // Broadcast to all admins
        title: 'New Employee Registration',
        message: `${cleanName} (${cleanEmail}) registered and is awaiting administrator approval.`,
        fullExplanation: `Employee ${cleanName} has submitted a registration request for Department: ${department || 'General'}. An administrator must review and approve their profile before they can access the mobile app and dashboard.`,
        type: 'employee_registration',
        actorId: newUser.id,
        actorName: cleanName,
      });
    } catch (err) {
      this.logger.error('Failed to create admin notification for employee registration', err);
    }

    // 2. Dispatch Dynamic Admin Email Alert
    this.sendNewEmployeeAlertToAdmins(cleanName, cleanEmail, department, designation);

    return {
      success: true,
      isApproved: false,
      message: 'Account registered successfully. Your profile is currently pending administrator verification. You will receive an approval email with mobile app access once approved.',
      user: {
        id: newUser.id,
        name: newUser.full_name,
        email: newUser.email,
        department: newUser.department,
        isActive: false,
      },
    };
  }

  private async sendLoginAlertToAdmins(userId: string, name: string, email: string, role: string) {
    try {
      const adminRes = await this.db.query(
        `SELECT email FROM users WHERE role::text IN ('main_admin', 'admin') AND is_active = TRUE AND id != $1`,
        [userId],
      );
      const adminEmails = adminRes.rows.map((r: any) => r.email).filter(Boolean);
      if (adminEmails.length > 0) {
        await this.emailService.sendAdminLoginSecurityAlert(adminEmails, name, email, role, new Date());
      }
    } catch (err) {
      this.logger.error('Failed to send login alert to admins', err);
    }
  }

  private async sendNewEmployeeAlertToAdmins(name: string, email: string, department?: string | null, designation?: string | null) {
    try {
      const adminRes = await this.db.query(
        `SELECT email FROM users WHERE role::text IN ('main_admin', 'admin') AND is_active = TRUE`,
      );
      const adminEmails = adminRes.rows.map((r: any) => r.email).filter(Boolean);
      if (adminEmails.length > 0) {
        await this.emailService.sendNewEmployeeRegisteredAlert(
          adminEmails,
          name,
          email,
          department || undefined,
          designation || undefined,
        );
      }
    } catch (err) {
      this.logger.error('Failed to send new employee alert to admins', err);
    }
  }

  async getProfile(userId: string) {
    const res = await this.db.query(
      `SELECT u.id, u.employee_code, u.email, u.full_name, u.role, u.department, u.designation, u.phone, u.avatar_url, u.home_latitude, u.home_longitude,
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
      employeeCode: row.employee_code || '',
      name: row.full_name,
      email: row.email,
      role: row.role,
      department: row.department,
      designation: row.designation,
      phone: row.phone,
      avatarUrl: row.avatar_url,
      homeLatitude: row.home_latitude === null ? null : Number(row.home_latitude),
      homeLongitude: row.home_longitude === null ? null : Number(row.home_longitude),
      assignedProjectIds: row.assigned_project_ids,
    };
  }

  async updateProfile(userId: string, data: any) {
    const fields: string[] = [];
    const values: any[] = [];
    let idx = 1;

    if (data.avatarUrl !== undefined || data.avatar_url !== undefined) {
      fields.push(`avatar_url = $${idx++}`);
      values.push(data.avatarUrl ?? data.avatar_url);
    }
    if (data.name !== undefined || data.full_name !== undefined || data.fullName !== undefined) {
      fields.push(`full_name = $${idx++}`);
      values.push(data.name ?? data.full_name ?? data.fullName);
    }
    if (data.email !== undefined && typeof data.email === 'string' && data.email.trim().length > 0) {
      fields.push(`email = $${idx++}`);
      values.push(data.email.trim().toLowerCase());
    }
    if (data.phone !== undefined) {
      fields.push(`phone = $${idx++}`);
      values.push(data.phone);
    }
    if (data.designation !== undefined) {
      fields.push(`designation = $${idx++}`);
      values.push(data.designation);
    }
    if (data.department !== undefined) {
      fields.push(`department = $${idx++}`);
      values.push(data.department);
    }

    if (data.homeLatitude !== undefined || data.home_latitude !== undefined || data.homeLongitude !== undefined || data.home_longitude !== undefined) {
      const latitude = data.homeLatitude ?? data.home_latitude ?? null;
      const longitude = data.homeLongitude ?? data.home_longitude ?? null;
      if ((latitude === null) !== (longitude === null)) {
        throw new BadRequestException('Both home location coordinates are required.');
      }
      if (latitude !== null && (!Number.isFinite(Number(latitude)) || Number(latitude) < -90 || Number(latitude) > 90 || !Number.isFinite(Number(longitude)) || Number(longitude) < -180 || Number(longitude) > 180)) {
        throw new BadRequestException('Home location coordinates are invalid.');
      }
      fields.push(`home_latitude = $${idx++}`);
      values.push(latitude === null ? null : Number(latitude));
      fields.push(`home_longitude = $${idx++}`);
      values.push(longitude === null ? null : Number(longitude));
    }

    if (!fields.length) {
      return this.getProfile(userId);
    }

    values.push(userId);
    const sql = `UPDATE users SET ${fields.join(', ')}, updated_at = NOW() WHERE id::text = $${idx} OR email ILIKE $${idx} RETURNING id, email, full_name, role, department, designation, phone, avatar_url, home_latitude, home_longitude`;
    const res = await this.db.query(sql, values);
    if (!res.rows.length) {
      throw new UnauthorizedException('User not found');
    }
    const r = res.rows[0];
    const userObj = await this.getProfile(r.id);
    return {
      ...userObj,
      user: userObj,
    };
  }

  async updateAvatar(userId: string, avatarUrl: string | null) {
    const res = await this.db.query(
      `UPDATE users SET avatar_url = $1, updated_at = NOW() WHERE id::text = $2 OR email ILIKE $2 RETURNING id, email, full_name, role, department, designation, phone, avatar_url, home_latitude, home_longitude`,
      [avatarUrl, userId],
    );
    if (!res.rows.length) {
      throw new UnauthorizedException('User not found');
    }
    const r = res.rows[0];
    const userObj = {
      id: r.id,
      name: r.full_name,
      email: r.email,
      role: r.role,
      department: r.department,
      designation: r.designation,
      phone: r.phone,
      avatarUrl: r.avatar_url,
      homeLatitude: r.home_latitude === null ? null : Number(r.home_latitude),
      homeLongitude: r.home_longitude === null ? null : Number(r.home_longitude),
    };
    return {
      ...userObj,
      user: userObj,
    };
  }

  async changePassword(userId: string, currentPass?: string, newPass?: string) {
    if (!newPass || newPass.length < 6) {
      throw new BadRequestException('New password must be at least 6 characters');
    }

    const res = await this.db.query('SELECT password_hash FROM users WHERE id = $1', [userId]);
    if (!res.rows.length) {
      throw new UnauthorizedException('User not found');
    }

    const isMatch = await bcrypt.compare(currentPass || '', res.rows[0].password_hash);
    if (!isMatch) {
      throw new BadRequestException('Current password does not match');
    }

    const newHash = await bcrypt.hash(newPass, 10);
    await this.db.query(
      'UPDATE users SET password_hash = $1, updated_at = clock_timestamp() WHERE id = $2',
      [newHash, userId],
    );

    return { success: true, message: 'Password updated successfully' };
  }

  async forgotPassword(email: string) {
    if (!email || !email.includes('@')) {
      throw new BadRequestException('Valid email address is required');
    }

    const cleanEmail = email.trim().toLowerCase();
    const res = await this.db.query('SELECT id, full_name, email FROM users WHERE email = $1 AND is_active = TRUE', [cleanEmail]);
    
    // Always return success even if email not found to prevent account enumeration
    if (!res.rows.length) {
      return { 
        success: true, 
        message: 'If this email is registered, a password reset verification code has been dispatched.' 
      };
    }

    const user = res.rows[0];
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    
    // Invalidate any active unused OTPs for this email
    await this.db.query(
      `UPDATE password_resets SET is_used = TRUE WHERE email = $1 AND is_used = FALSE`,
      [cleanEmail],
    );

    // Insert new OTP with 15-minute expiration
    await this.db.query(
      `INSERT INTO password_resets (id, email, otp, expires_at, is_used, created_at)
       VALUES (gen_random_uuid(), $1, $2, clock_timestamp() + INTERVAL '15 minutes', FALSE, clock_timestamp())`,
      [cleanEmail, otp],
    );

    // Dispatch branded email via Resend
    await this.emailService.sendPasswordResetOtp(user.email, user.full_name, otp, 15);

    // Store in audit logs
    try {
      await this.db.query(
        `INSERT INTO audit_logs (user_id, user_name, user_role, action, entity_type, entity_id, details)
         VALUES ($1, $2, 'main_admin', 'PASSWORD_RESET_OTP_GENERATED', 'users', $3, $4)`,
        [user.id, user.full_name || 'User', String(user.id), JSON.stringify({ email: cleanEmail, expires_in_minutes: 15, timestamp: new Date().toISOString() })]
      );
    } catch (_) {
      // Audit log error should not block password reset delivery
    }

    return {
      success: true,
      message: `Password reset verification code has been sent to ${cleanEmail}`,
    };
  }

  async verifyOtp(email: string, otp: string) {
    if (!email || !email.includes('@') || !otp) {
      throw new BadRequestException('Valid email and OTP code are required');
    }

    const cleanEmail = email.trim().toLowerCase();
    const cleanOtp = otp.trim();

    const res = await this.db.query(
      `SELECT id, expires_at 
       FROM password_resets 
       WHERE email = $1 AND otp = $2 AND is_used = FALSE AND expires_at > clock_timestamp()
       ORDER BY created_at DESC 
       LIMIT 1`,
      [cleanEmail, cleanOtp],
    );

    if (!res.rows.length) {
      throw new BadRequestException('Invalid or expired verification code. Please request a new code.');
    }

    return {
      success: true,
      valid: true,
      message: 'Verification code is valid.',
    };
  }

  async resetPassword(email: string, tokenOrOtp: string, newPass: string) {
    if (!newPass || newPass.length < 6) {
      throw new BadRequestException('New password must be at least 6 characters');
    }
    if (!email || !email.includes('@') || !tokenOrOtp) {
      throw new BadRequestException('Email and OTP verification code are required');
    }

    const cleanEmail = email.trim().toLowerCase();
    const cleanOtp = tokenOrOtp.trim();

    // Verify OTP record
    const otpRes = await this.db.query(
      `SELECT id 
       FROM password_resets 
       WHERE email = $1 AND otp = $2 AND is_used = FALSE AND expires_at > clock_timestamp()
       ORDER BY created_at DESC 
       LIMIT 1`,
      [cleanEmail, cleanOtp],
    );

    if (!otpRes.rows.length) {
      throw new BadRequestException('Invalid or expired verification code. Please request a new code.');
    }

    const resetId = otpRes.rows[0].id;

    // Verify user exists and is active
    const userRes = await this.db.query(
      'SELECT id, full_name, email FROM users WHERE email = $1 AND is_active = TRUE',
      [cleanEmail],
    );
    if (!userRes.rows.length) {
      throw new BadRequestException('User account not found or deactivated');
    }

    const user = userRes.rows[0];

    // Mark OTP as used
    await this.db.query('UPDATE password_resets SET is_used = TRUE WHERE id = $1', [resetId]);

    // Hash new password and update user record
    const newHash = await bcrypt.hash(newPass, 10);
    await this.db.query(
      'UPDATE users SET password_hash = $1, updated_at = clock_timestamp() WHERE id = $2',
      [newHash, user.id],
    );

    // Dispatch password changed confirmation email via Resend
    await this.emailService.sendPasswordChangedConfirmation(user.email, user.full_name);

    // Audit log
    try {
      await this.db.query(
        `INSERT INTO audit_logs (user_id, user_name, user_role, action, entity_type, entity_id, details)
         VALUES ($1, $2, 'main_admin', 'PASSWORD_RESET_COMPLETED', 'users', $3, $4)`,
        [user.id, user.full_name || 'User', String(user.id), JSON.stringify({ email: cleanEmail, timestamp: new Date().toISOString() })]
      );
    } catch (_) {
      // Audit log error should not block password reset completion
    }

    return { 
      success: true, 
      message: 'Your password has been successfully updated. Please sign in with your new credentials.' 
    };
  }
}
