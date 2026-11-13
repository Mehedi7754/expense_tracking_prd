import { Injectable, Logger, BadRequestException, ForbiddenException, ConflictException } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CheckInDto } from './dto/check-in.dto';

import { EmailService } from '../email/email.service';

export interface AttendanceRecord {
  id: string;
  userId: string;
  userName: string;
  userEmail: string;
  department: string;
  designation: string;
  avatarUrl?: string;
  date: string;
  sessionType: 'morning' | 'afternoon';
  loginTime: string;
  latitude: number | null;
  longitude: number | null;
  addressText: string;
  deviceInfo: string;
  workMode: string;
  status: string;
  notes: string;
  createdAt: string;
}

export interface ShiftDefinition {
  id: string;
  name: string;
  morningStartHour: number;
  morningStartMinute?: number;
  breakStartHour?: number;
  breakStartMinute?: number;
  breakEndHour?: number;
  breakEndMinute?: number;
  afternoonEndHour: number;
  afternoonEndMinute?: number;
  morningEndHour?: number;
  afternoonStartHour?: number;
  weekendDays?: number[];
  isDefault?: boolean;
}

@Injectable()
export class AttendanceService {
  private readonly logger = new Logger(AttendanceService.name);

  constructor(
    private readonly db: DatabaseService,
    private readonly notificationsService: NotificationsService,
    private readonly emailService: EmailService,
  ) {}

  getDhakaDateStr(date?: Date): string {
    const d = date || new Date();
    const tz = this.officeTimingSettings.timezone || 'Asia/Dhaka';
    const localDate = new Date(d.toLocaleString('en-US', { timeZone: tz }));
    const yyyy = localDate.getFullYear();
    const mm = String(localDate.getMonth() + 1).padStart(2, '0');
    const dd = String(localDate.getDate()).padStart(2, '0');
    return `${yyyy}-${mm}-${dd}`;
  }

  private officeTimingSettings = {
    morningStartHour: 9,
    morningStartMinute: 0,
    breakStartHour: 13,
    breakStartMinute: 0,
    breakEndHour: 14,
    breakEndMinute: 0,
    morningEndHour: 13,
    afternoonStartHour: 14,
    afternoonEndHour: 18,
    afternoonEndMinute: 0,
    weekendDays: [5, 6],
    deductionType: 'rate_based',
    fullDayDeductionAmount: 1.0,
    halfDayDeductionAmount: 0.5,
    gracePeriodMinutes: 15,
    timezone: 'Asia/Dhaka',
    shifts: [
      {
        id: 'shift_default',
        name: 'General Office Shift',
        morningStartHour: 9,
        breakStartHour: 13,
        breakEndHour: 14,
        morningEndHour: 13,
        afternoonStartHour: 14,
        afternoonEndHour: 18,
        weekendDays: [5, 6],
        isDefault: true,
      },
      {
        id: 'shift_morning',
        name: 'Early Morning Shift',
        morningStartHour: 7,
        breakStartHour: 11,
        breakEndHour: 12,
        morningEndHour: 11,
        afternoonStartHour: 12,
        afternoonEndHour: 15,
        weekendDays: [5, 6],
        isDefault: false,
      },
      {
        id: 'shift_evening',
        name: 'Evening Shift',
        morningStartHour: 14,
        breakStartHour: 18,
        breakEndHour: 19,
        morningEndHour: 18,
        afternoonStartHour: 19,
        afternoonEndHour: 22,
        weekendDays: [7],
        isDefault: false,
      },
    ] as ShiftDefinition[],
    userShifts: {} as Record<string, string>,
    officeLatitude: 23.7925,
    officeLongitude: 90.4078,
    officeName: 'Office',
    officeAddress: '',
    geofenceRadiusMeters: 200,
    isGeofenceEnforced: true,
  };

  async getTimingSettings() {
    try {
      const res = await this.db.query(
        `SELECT value FROM app_settings WHERE key = 'attendance_timing_settings'`,
      );
      if (res.rows.length > 0) {
        const parsed = JSON.parse(res.rows[0].value);
        this.officeTimingSettings = { ...this.officeTimingSettings, ...parsed };
      }
    } catch (_) {}
    return this.officeTimingSettings;
  }

  async updateTimingSettings(settings: Partial<typeof this.officeTimingSettings>) {
    if (settings.officeLatitude !== undefined || settings.officeLongitude !== undefined || settings.geofenceRadiusMeters !== undefined) {
      const lat = settings.officeLatitude ?? this.officeTimingSettings.officeLatitude;
      const lng = settings.officeLongitude ?? this.officeTimingSettings.officeLongitude;
      const radius = settings.geofenceRadiusMeters ?? this.officeTimingSettings.geofenceRadiusMeters;
      if (!Number.isFinite(lat) || lat < -90 || lat > 90 ||
          !Number.isFinite(lng) || lng < -180 || lng > 180 ||
          !Number.isFinite(radius) || radius < 25 || radius > 1000) {
        throw new BadRequestException('Invalid office coordinates or geofence radius');
      }
    }
    this.officeTimingSettings = {
      ...this.officeTimingSettings,
      ...settings,
    };

    if (settings.weekendDays) {
      this.officeTimingSettings.weekendDays = settings.weekendDays;
    }

    // Ensure default shift and top-level timings remain tightly synchronized
    if (this.officeTimingSettings.shifts && this.officeTimingSettings.shifts.length > 0) {
      const defaultShift =
        this.officeTimingSettings.shifts.find((s) => s.isDefault) || this.officeTimingSettings.shifts[0];
      if (settings.weekendDays && defaultShift) {
        defaultShift.weekendDays = settings.weekendDays;
      }
      if (settings.breakStartHour !== undefined && !settings.shifts) {
        defaultShift.breakStartHour = settings.breakStartHour;
        defaultShift.morningEndHour = settings.breakStartHour;
      }
      if (settings.breakEndHour !== undefined && !settings.shifts) {
        defaultShift.breakEndHour = settings.breakEndHour;
        defaultShift.afternoonStartHour = settings.breakEndHour;
      }
      if (settings.morningStartHour !== undefined && !settings.shifts) {
        defaultShift.morningStartHour = settings.morningStartHour;
      }
      if (settings.afternoonEndHour !== undefined && !settings.shifts) {
        defaultShift.afternoonEndHour = settings.afternoonEndHour;
      }
      if (settings.shifts && defaultShift) {
        this.officeTimingSettings.morningStartHour = defaultShift.morningStartHour;
        this.officeTimingSettings.breakStartHour = defaultShift.breakStartHour ?? defaultShift.morningEndHour ?? 13;
        this.officeTimingSettings.breakEndHour = defaultShift.breakEndHour ?? defaultShift.afternoonStartHour ?? 14;
        this.officeTimingSettings.morningEndHour = this.officeTimingSettings.breakStartHour;
        this.officeTimingSettings.afternoonStartHour = this.officeTimingSettings.breakEndHour;
        this.officeTimingSettings.afternoonEndHour = defaultShift.afternoonEndHour;
        if (defaultShift.weekendDays) {
          this.officeTimingSettings.weekendDays = defaultShift.weekendDays;
        }
      }
    }

    try {
      await this.db.query(
        `CREATE TABLE IF NOT EXISTS app_settings (key VARCHAR(255) PRIMARY KEY, value TEXT, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)`,
      );
      await this.db.query(
        `INSERT INTO app_settings (key, value, updated_at)
         VALUES ('attendance_timing_settings', $1, CURRENT_TIMESTAMP)
         ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = CURRENT_TIMESTAMP`,
        [JSON.stringify(this.officeTimingSettings)],
      );
    } catch (e) {
      this.logger.warn(`Could not persist timing settings to db: ${e}`);
      throw e;
    }
    return this.officeTimingSettings;
  }

  private getShiftForUser(userId: string): ShiftDefinition {
    const shiftId = this.officeTimingSettings.userShifts?.[userId];
    if (shiftId && this.officeTimingSettings.shifts) {
      const found = this.officeTimingSettings.shifts.find((s) => s.id === shiftId);
      if (found) return found;
    }
    const defaultShift = this.officeTimingSettings.shifts?.find((s) => s.isDefault);
    return defaultShift || {
      id: 'shift_default',
      name: 'General Office Shift',
      morningStartHour: 9,
      breakStartHour: 13,
      breakEndHour: 14,
      morningEndHour: 13,
      afternoonStartHour: 14,
      afternoonEndHour: 18,
      weekendDays: [5, 6],
      isDefault: true,
    };
  }

  async checkIn(userId: string, dto: CheckInDto): Promise<AttendanceRecord> {
    await this.getTimingSettings();

    // 1. Check user role — Super Admin & Finance are exempt from attendance rules, but allowed to check in for testing
    const userRoleRes = await this.db.query('SELECT role, full_name, email FROM users WHERE id = $1', [userId]);
    const user = userRoleRes.rows[0];
    if (user?.role === 'main_admin' || user?.role === 'finance') {
      this.logger.log(`Privileged user ${userId} (${user.role}) is recording check-in.`);
    }

    const tz = this.officeTimingSettings.timezone || 'Asia/Dhaka';
    const dhakaNow = new Date(new Date().toLocaleString('en-US', { timeZone: tz }));
    const targetDateForCheck = dto.date && /^\d{4}-\d{2}-\d{2}$/.test(dto.date) ? dto.date : this.getDhakaDateStr(dhakaNow);
    const assignedLocationInfo = await this.getAssignedWorkLocation(userId, targetDateForCheck);

    let workMode = dto.workMode || dto.work_mode;
    if (!workMode) {
      workMode = assignedLocationInfo?.workLocation || 'office';
    }

    let fieldSiteNote = '';
    if (assignedLocationInfo && assignedLocationInfo.workLocation) {
      fieldSiteNote += ` [Assigned: ${assignedLocationInfo.workLocation.toUpperCase()}${assignedLocationInfo.notes ? ` - ${assignedLocationInfo.notes}` : ''}]`;
    }

    if (workMode === 'field') {
      const fieldProjectId = dto.fieldProjectId || dto.field_project_id || assignedLocationInfo?.projectId;
      if (!fieldProjectId) {
        throw new BadRequestException('Select a project with a saved field site before checking in.');
      }
      const isPrivileged = user?.role === 'main_admin' || user?.role === 'finance' || user?.role === 'finance_manager';
      const siteRes = await this.db.query(
        `SELECT p.id, p.name, p.project_code, p.site_latitude, p.site_longitude
         FROM projects p
         WHERE p.id::text = $1
           AND ($3::boolean OR p.created_by = $2 OR EXISTS (
             SELECT 1 FROM project_members pm WHERE pm.project_id = p.id AND pm.user_id = $2
           ))
         LIMIT 1`,
        [fieldProjectId, userId, isPrivileged],
      );
      const site = siteRes.rows[0];
      if (!site) throw new ForbiddenException('You are not assigned to the selected field project.');
      if (site.site_latitude == null || site.site_longitude == null) {
        throw new BadRequestException('The selected project has no saved site pin. Ask an admin to set its field site.');
      }
      const latitude = Number(dto.latitude);
      const longitude = Number(dto.longitude);
      const siteLatitude = Number(site.site_latitude);
      const siteLongitude = Number(site.site_longitude);
      const toRadians = (degrees: number) => (degrees * Math.PI) / 180;
      const earthRadiusMeters = 6371000;
      const deltaLat = toRadians(siteLatitude - latitude);
      const deltaLng = toRadians(siteLongitude - longitude);
      const a = Math.sin(deltaLat / 2) ** 2 +
        Math.cos(toRadians(latitude)) * Math.cos(toRadians(siteLatitude)) * Math.sin(deltaLng / 2) ** 2;
      const distanceMeters = earthRadiusMeters * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
      const radiusMeters = Number(this.officeTimingSettings.geofenceRadiusMeters) || 200;
      if (this.officeTimingSettings.isGeofenceEnforced && distanceMeters > radiusMeters) {
        throw new BadRequestException(`Outside the ${site.name} field site geofence (${Math.round(distanceMeters)}m away; ${radiusMeters}m allowed).`);
      }
      fieldSiteNote = ` [Field project: ${site.name} (${site.project_code})] [Site geofence: ${Math.round(distanceMeters)}m from pin]`;
    } else if (workMode === 'office') {
      const isPrivileged = user?.role === 'main_admin' || user?.role === 'finance' || user?.role === 'finance_manager';
      if (!isPrivileged && this.officeTimingSettings.isGeofenceEnforced) {
        if (dto.latitude == null || dto.longitude == null) {
          throw new BadRequestException('GPS coordinates are required to check in from the office.');
        }
        const userLat = Number(dto.latitude);
        const userLng = Number(dto.longitude);
        const officeLat = Number(this.officeTimingSettings.officeLatitude);
        const officeLng = Number(this.officeTimingSettings.officeLongitude);
        const toRadians = (degrees: number) => (degrees * Math.PI) / 180;
        const earthRadiusMeters = 6371000;
        const deltaLat = toRadians(officeLat - userLat);
        const deltaLng = toRadians(officeLng - userLng);
        const a = Math.sin(deltaLat / 2) ** 2 +
          Math.cos(toRadians(userLat)) * Math.cos(toRadians(officeLat)) * Math.sin(deltaLng / 2) ** 2;
        const distanceMeters = earthRadiusMeters * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        const radiusMeters = Number(this.officeTimingSettings.geofenceRadiusMeters) || 200;
        if (distanceMeters > radiusMeters) {
          throw new BadRequestException(`Outside the office geofence perimeter (${Math.round(distanceMeters)}m away; ${radiusMeters}m allowed).`);
        }
        fieldSiteNote = ` [Office geofence: ${Math.round(distanceMeters)}m from office]`;
      }
    }

    // 2. Resolve local office hour (Bangladesh Standard Time: UTC+6) and assigned user shift
    const currentHour = dhakaNow.getHours();
    const userShift = this.getShiftForUser(userId);

    const morningStart = userShift.morningStartHour ?? 9;
    const breakStart = userShift.breakStartHour ?? userShift.morningEndHour ?? 13;
    const breakEnd = userShift.breakEndHour ?? userShift.afternoonStartHour ?? 14;
    const afternoonEnd = userShift.afternoonEndHour ?? 18;

    let session: 'morning' | 'afternoon';
    const explicit = (dto.sessionType || dto.session_type || '').toLowerCase();
    if (explicit === 'morning') {
      session = 'morning';
    } else if (explicit === 'afternoon') {
      session = 'afternoon';
    } else {
      session = currentHour < breakEnd ? 'morning' : 'afternoon';
    }

    const targetDate = dto.date && /^\d{4}-\d{2}-\d{2}$/.test(dto.date) ? dto.date : this.getDhakaDateStr(dhakaNow);

    // Enforce check-out validity: Afternoon checkout is valid only for the same day till midnight (12:00 AM).
    // An employee cannot checkout before checking in for today.
    // (If not checked out by midnight, the day automatically becomes half_day, and next day requires fresh check-in).
    if (session === 'afternoon' && user?.role !== 'main_admin') {
      const morningRes = await this.db.query(
        `SELECT id FROM attendance_records
         WHERE user_id = $1 AND date = $2 AND session_type = 'morning'`,
        [userId, targetDate],
      );
      if (morningRes.rows.length === 0) {
        throw new BadRequestException(
          'Cannot check out before checking in for today. Please log morning check-in first.',
        );
      }
    }

    const currentMinute = dhakaNow.getMinutes();
    const gracePeriod = this.officeTimingSettings.gracePeriodMinutes ?? 15;
    const isCheckOut = session === 'afternoon';

    let isLate = false;
    if (session === 'morning') {
      if (currentHour > morningStart || (currentHour === morningStart && currentMinute > gracePeriod)) {
        isLate = true;
      }
    } else if (session === 'afternoon') {
      if (currentHour > breakEnd || (currentHour === breakEnd && currentMinute > gracePeriod)) {
        isLate = true;
      }
    }

    const currentTotalMinutes = currentHour * 60 + currentMinute;
    const afternoonEndMinutes = afternoonEnd * 60;
    const isEarly = isCheckOut && (currentTotalMinutes < (afternoonEndMinutes - gracePeriod));

    const address = dto.addressText || dto.address_text || '';
    const deviceInfo = dto.deviceInfo || '';
    let notes = dto.notes || '';
    notes = `${notes}${fieldSiteNote}`.trim();

    const hasExplicitStatus = Boolean(dto.status);
    let statusVal = 'present';
    if (hasExplicitStatus) {
      statusVal = dto.status!;
    } else {
      statusVal = isLate ? 'late' : 'present';
    }

    if (!hasExplicitStatus) {
      if (isEarly) {
        notes = notes ? `${notes} [Checked out before time]` : '[Checked out before time]';
      } else if (isLate && !notes.toLowerCase().includes('late')) {
        notes = notes ? `${notes} [Late check-in]` : '[Late check-in]';
      }
    }

    // Check if record exists for this user, date and session
    const existing = await this.db.query(
      `SELECT id FROM attendance_records
       WHERE user_id = $1 AND date = $2 AND session_type = $3`,
      [userId, targetDate, session],
    );

    let recordId: string;

    if (existing.rows.length > 0) {
      const res = await this.db.query(
        `UPDATE attendance_records
         SET login_time = CASE WHEN date = (clock_timestamp() AT TIME ZONE 'Asia/Dhaka')::date THEN clock_timestamp() ELSE login_time END,
             latitude = $2, longitude = $3, address_text = $4, device_info = $5, status = $6, notes = $7, work_mode = $8
         WHERE id = $1
         RETURNING id`,
        [existing.rows[0].id, dto.latitude, dto.longitude, address, deviceInfo, statusVal, notes, workMode],
      );
      recordId = res.rows[0].id;
      this.logger.log(`Updated attendance check-in for user ${userId} (${session}) on ${targetDate}`);
    } else {
      const res = await this.db.query(
        `INSERT INTO attendance_records (user_id, date, session_type, login_time, latitude, longitude, address_text, device_info, status, notes, work_mode)
         VALUES ($1, $2::date, $3::varchar(20), CASE WHEN $2::date = (clock_timestamp() AT TIME ZONE 'Asia/Dhaka')::date THEN clock_timestamp() ELSE ($2::text || ' ' || (CASE WHEN $3::varchar(20) = 'morning' THEN '09:00:00+06' ELSE '14:00:00+06' END))::timestamptz END, $4, $5, $6, $7, $8, $9, $10)
         RETURNING id`,
        [userId, targetDate, session, dto.latitude, dto.longitude, address, deviceInfo, statusVal, notes, workMode],
      );
      recordId = res.rows[0].id;
      this.logger.log(`Created new attendance check-in for user ${userId} (${session}) on ${targetDate} at [${dto.latitude}, ${dto.longitude}]`);
    }

    const fetched = await this.getRecordById(recordId);
    if (!fetched) {
      throw new BadRequestException('Failed to retrieve recorded attendance');
    }

    try {
      const userRes = await this.db.query('SELECT full_name, email, avatar_url FROM users WHERE id = $1', [userId]);
      const empName = userRes.rows[0]?.full_name || 'Team member';
      const empEmail = userRes.rows[0]?.email || '';
      const empAvatar = userRes.rows[0]?.avatar_url || null;
      const recordedAt = new Date(fetched.loginTime);
      const notifTz = this.officeTimingSettings.timezone || 'Asia/Dhaka';
      const timeStr = recordedAt.toLocaleTimeString('en-US', {
        timeZone: notifTz, hour: '2-digit', minute: '2-digit',
      });
      const dateStr = recordedAt.toLocaleDateString('en-US', { timeZone: notifTz });
      
      const statusTag = isLate ? '⚠️ LATE' : '✅ ON TIME';
      const checkoutTag = isEarly ? '⚠️ BEFORE TIME' : '✅ ON TIME';

      // Notify employee with attendance confirmation
      await this.notificationsService.create({
        userId,
        title: isCheckOut
          ? (isEarly ? 'Attendance Check-Out (Before Time) ⚠️' : 'Attendance Check-Out 📍')
          : (isLate ? 'Attendance Recorded (Late) ⚠️' : 'Attendance Recorded 📍'),
        message: isCheckOut
          ? (isEarly
              ? `Your check-out was recorded before scheduled shift end at ${timeStr}.`
              : `Your check-out was successfully recorded at ${timeStr}.`)
          : `Your check-in for the ${session} session was successfully recorded at ${timeStr}.`,
        fullExplanation: isCheckOut
          ? `Attendance check-out verified at ${timeStr}. Shift: ${userShift.name} (Scheduled end: ${afternoonEnd}:00). GPS Location: [${dto.latitude ?? 'N/A'}, ${dto.longitude ?? 'N/A'}]. Address: ${address || 'Office Premises'}. Status: ${isEarly ? 'Checked Out Before Time' : 'Checked Out'}.`
          : `Attendance check-in verified at ${timeStr}. Shift: ${userShift.name}. GPS Location: [${dto.latitude ?? 'N/A'}, ${dto.longitude ?? 'N/A'}]. Address: ${address || 'Office Premises'}. Status: ${isLate ? 'Late' : 'Present'}.`,
        type: isCheckOut
          ? (isEarly ? 'attendance_early' : 'attendance_reminder')
          : (isLate ? 'attendance_late' : 'attendance_reminder'),
        actorId: userId,
        actorName: empName,
        actorAvatarUrl: empAvatar,
      });

      // Send Email to Employee
      if (this.emailService && empEmail) {
        await this.emailService.sendCheckInConfirmation(
          empEmail,
          empName,
          session,
          timeStr,
          address || 'Office Premises',
          isLate,
          isEarly,
        );
      }

      // Notify Super Admin & Managers about the employee check-in/check-out (FCM Push)
      const adminsRes = await this.db.query(
        `SELECT id FROM users WHERE role IN ('main_admin', 'project_manager') AND is_active = TRUE AND id != $1`,
        [userId],
      );
      for (const admin of adminsRes.rows) {
        await this.notificationsService.create({
          userId: admin.id,
          title: isCheckOut
            ? `Employee Checked Out: ${empName} (${checkoutTag})`
            : `Employee Checked In: ${statusTag}`,
          message: isCheckOut
            ? (isEarly
                ? `${empName} checked out early before scheduled time at ${timeStr}.`
                : `${empName} checked out at ${timeStr}.`)
            : `${empName} recorded attendance for ${session} session at ${timeStr}.`,
          fullExplanation: isCheckOut
            ? `${empName} checked out on ${dateStr} at ${timeStr}. Shift: ${userShift.name} (Scheduled end: ${afternoonEnd}:00, ${isEarly ? 'Early departure' : 'On time'}). Location coordinates: [${dto.latitude ?? 'N/A'}, ${dto.longitude ?? 'N/A'}]. Address: ${address || 'Office Premises'}.`
            : `${empName} logged in for the ${session} session on ${dateStr} at ${timeStr}. Location coordinates: [${dto.latitude ?? 'N/A'}, ${dto.longitude ?? 'N/A'}]. Address: ${address || 'Office Premises'}.`,
          type: isCheckOut
            ? (isEarly ? 'attendance_early' : 'attendance_reminder')
            : (isLate ? 'attendance_late' : 'attendance_reminder'),
          actorId: userId,
          actorName: empName,
          actorAvatarUrl: empAvatar,
        });
      }
    } catch (e) {
      this.logger.warn(`Could not create attendance notifications/emails: ${e}`);
    }

    return fetched;
  }

  async getRecordById(id: string): Promise<AttendanceRecord | null> {
    const res = await this.db.query(
      `SELECT a.id, a.user_id as "userId", u.full_name as "userName", u.email as "userEmail",
              COALESCE(u.department, '') as department, COALESCE(u.designation, '') as designation,
              u.avatar_url as "avatarUrl", a.date::text, a.session_type as "sessionType",
              a.login_time::text as "loginTime", a.latitude, a.longitude,
              a.address_text as "addressText", a.device_info as "deviceInfo",
              a.status, a.notes, a.work_mode as "workMode", a.created_at::text as "createdAt"
       FROM attendance_records a
       JOIN users u ON a.user_id = u.id
       WHERE a.id = $1`,
      [id],
    );
    return res.rows[0] || null;
  }

  async getTodayRecords(): Promise<AttendanceRecord[]> {
    return this.getRecordsByDate(this.getDhakaDateStr());
  }

  async getRecordsByDate(dateStr?: string, userId?: string): Promise<AttendanceRecord[]> {
    let sql = `SELECT a.id, a.user_id as "userId", u.full_name as "userName", u.email as "userEmail",
                      COALESCE(u.department, '') as department, COALESCE(u.designation, '') as designation,
                      u.avatar_url as "avatarUrl", a.date::text, a.session_type as "sessionType",
                      a.login_time::text as "loginTime", a.latitude, a.longitude,
                      a.address_text as "addressText", a.device_info as "deviceInfo",
                      a.status, a.notes, a.work_mode as "workMode", a.created_at::text as "createdAt"
               FROM attendance_records a
               JOIN users u ON a.user_id = u.id
               WHERE u.is_active = TRUE`;
    const params: any[] = [];
    if (dateStr) {
      params.push(dateStr);
      sql += ` AND a.date = $${params.length}`;
    } else if (!userId) {
      params.push(this.getDhakaDateStr());
      sql += ` AND a.date = $${params.length}`;
    }

    if (userId) {
      params.push(userId);
      sql += ` AND a.user_id = $${params.length}`;
    }
    sql += ' ORDER BY a.date DESC, a.login_time DESC LIMIT 100';
    const res = await this.db.query(sql, params);
    return res.rows;
  }

  async getMonthlyRecords(userId: string, year: number, month: number): Promise<AttendanceRecord[]> {
    const startDate = `${year}-${String(month).padStart(2, '0')}-01`;
    const nextMonthYear = month === 12 ? year + 1 : year;
    const nextMonthVal = month === 12 ? 1 : month + 1;
    const endDate = `${nextMonthYear}-${String(nextMonthVal).padStart(2, '0')}-01`;

    const res = await this.db.query(
      `SELECT a.id, a.user_id as "userId", u.full_name as "userName", u.email as "userEmail",
              COALESCE(u.department, '') as department, COALESCE(u.designation, '') as designation,
              u.avatar_url as "avatarUrl", a.date::text, a.session_type as "sessionType",
              a.login_time::text as "loginTime", a.latitude, a.longitude,
              a.address_text as "addressText", a.device_info as "deviceInfo",
              a.status, a.notes, a.work_mode as "workMode", a.created_at::text as "createdAt"
       FROM attendance_records a
       JOIN users u ON a.user_id = u.id
       WHERE a.user_id = $1 AND a.date >= $2 AND a.date < $3 AND u.is_active = TRUE
       ORDER BY a.date ASC, a.session_type ASC`,
      [userId, startDate, endDate],
    );
    return res.rows;
  }

  async getAllMonthlyRecords(year: number, month: number): Promise<AttendanceRecord[]> {
    const startDate = `${year}-${String(month).padStart(2, '0')}-01`;
    const nextMonthYear = month === 12 ? year + 1 : year;
    const nextMonthVal = month === 12 ? 1 : month + 1;
    const endDate = `${nextMonthYear}-${String(nextMonthVal).padStart(2, '0')}-01`;

    const res = await this.db.query(
      `SELECT a.id, a.user_id as "userId", u.full_name as "userName", u.email as "userEmail",
              COALESCE(u.department, '') as department, COALESCE(u.designation, '') as designation,
              u.avatar_url as "avatarUrl", a.date::text, a.session_type as "sessionType",
              a.login_time::text as "loginTime", a.latitude, a.longitude,
              a.address_text as "addressText", a.device_info as "deviceInfo",
              a.status, a.notes, a.work_mode as "workMode", a.created_at::text as "createdAt"
       FROM attendance_records a
       JOIN users u ON a.user_id = u.id
       WHERE a.date >= $1 AND a.date < $2 AND u.is_active = TRUE
       ORDER BY a.date ASC, a.session_type ASC`,
      [startDate, endDate],
    );
    return res.rows;
  }

  async getDailyOverview(dateStr?: string) {
    await this.getTimingSettings();
    const targetDate = dateStr || this.getDhakaDateStr();
    const targetDateObj = new Date(targetDate.includes('T') ? targetDate : `${targetDate}T00:00:00Z`);
    const dayOfWeek = targetDateObj.getUTCDay() === 0 ? 7 : targetDateObj.getUTCDay();

    // Query active non-exempt users who existed on or before target date
    const usersRes = await this.db.query(
      `SELECT id, full_name as "userName", email as "userEmail", role,
              COALESCE(department, '') as department, COALESCE(designation, '') as designation,
              avatar_url as "avatarUrl"
       FROM users
       WHERE is_active = TRUE 
         AND role NOT IN ('main_admin', 'finance')
         AND created_at::date <= $1::date
       ORDER BY full_name ASC`,
      [targetDate],
    );

    const recordsRes = await this.db.query(
      `SELECT a.id, a.user_id as "userId", u.full_name as "userName", u.email as "userEmail",
              COALESCE(u.department, '') as department, COALESCE(u.designation, '') as designation,
              u.avatar_url as "avatarUrl", a.date::text, a.session_type as "sessionType",
              a.login_time::text as "loginTime", a.latitude, a.longitude,
              a.address_text as "addressText", a.device_info as "deviceInfo",
              a.status, a.notes, a.work_mode as "workMode", a.created_at::text as "createdAt"
       FROM attendance_records a
       JOIN users u ON a.user_id = u.id
       WHERE a.date = $1 AND u.is_active = TRUE`,
      [targetDate],
    );

    const byUser: Record<string, { morning?: any; afternoon?: any; confirmedAbsent?: boolean }> = {};
    for (const r of recordsRes.rows) {
      if (!byUser[r.userId]) byUser[r.userId] = {};
      if (r.sessionType === 'morning') byUser[r.userId].morning = r;
      if (r.sessionType === 'afternoon') byUser[r.userId].afternoon = r;
      if (r.status === 'confirmed_absent') byUser[r.userId].confirmedAbsent = true;
    }

    let presentCount = 0;
    let halfDayCount = 0;
    let missingCount = 0;

    const workLocsRes = await this.db.query(
      `SELECT user_id, work_location, project_id, notes
       FROM employee_work_locations
       WHERE date = $1`,
      [targetDate],
    );
    const locByUser: Record<string, any> = {};
    for (const wl of workLocsRes.rows) {
      locByUser[wl.user_id] = wl;
    }

    const employees = usersRes.rows.map((user: any) => {
      const shift = this.getShiftForUser(user.id);
      const shiftWeekends = shift?.weekendDays || this.officeTimingSettings.weekendDays || [5, 6];
      const isWeekend = shiftWeekends.includes(dayOfWeek);
      const rec = byUser[user.id];
      const assignedLoc = locByUser[user.id];

      let status = 'missing';
      if (isWeekend) {
        status = 'weekend';
      } else if (rec?.morning && rec?.afternoon) {
        status = 'present';
        presentCount++;
      } else if (rec?.morning || rec?.afternoon) {
        status = 'half_day';
        halfDayCount++;
      } else if (rec?.confirmedAbsent) {
        status = 'confirmed_absent';
        missingCount++;
      } else {
        status = 'missing';
        missingCount++;
      }

      return {
        userId: user.id,
        userName: user.userName,
        userEmail: user.userEmail,
        department: user.department,
        designation: user.designation,
        role: user.role,
        avatarUrl: user.avatarUrl || '',
        date: targetDate,
        status,
        assignedWorkLocation: assignedLoc?.work_location || 'office',
        assignedLocationProjectId: assignedLoc?.project_id || null,
        assignedLocationNotes: assignedLoc?.notes || null,
        morning: rec?.morning || null,
        afternoon: rec?.afternoon || null,
      };
    });

    return {
      date: targetDate,
      totalEmployees: employees.length,
      presentCount,
      halfDayCount,
      missingCount,
      employees,
    };
  }

  async getSummary(userId?: string) {
    const todayStr = this.getDhakaDateStr();
    let whereClause = `WHERE date = $1`;
    const params: any[] = [todayStr];

    if (userId) {
      params.push(userId);
      whereClause += ` AND user_id = $2`;
    }

    const res = await this.db.query(
      `SELECT
         COUNT(DISTINCT user_id) FILTER (WHERE session_type = 'morning' AND status = 'present') as "morningPresent",
         COUNT(DISTINCT user_id) FILTER (WHERE session_type = 'afternoon' AND status = 'present') as "afternoonPresent",
         COUNT(DISTINCT user_id) FILTER (WHERE status = 'present') as "totalPresent"
       FROM attendance_records
       ${whereClause}`,
      params,
    );

    const totalUsersRes = await this.db.query(`SELECT COUNT(*) as total FROM users WHERE role NOT IN ('main_admin', 'finance') AND is_active = TRUE`);
    const totalEmployees = parseInt(totalUsersRes.rows[0]?.total || '0', 10);

    const morningPresent = parseInt(res.rows[0]?.morningPresent || '0', 10);
    const afternoonPresent = parseInt(res.rows[0]?.afternoonPresent || '0', 10);
    const totalPresent = parseInt(res.rows[0]?.totalPresent || '0', 10);

    return {
      date: todayStr,
      totalEmployees,
      morningPresent,
      afternoonPresent,
      totalPresent,
      absentEmployees: Math.max(0, totalEmployees - totalPresent),
    };
  }

  async getEmployeeAttendanceStats(userId: string, monthStr?: string) {
    await this.getTimingSettings();
    const userShift = this.getShiftForUser(userId);
    const weekendDays = userShift.weekendDays || [5, 6];

    // Fetch employee creation date to ensure calculations start from joining date
    const userRes = await this.db.query('SELECT created_at FROM users WHERE id = $1', [userId]);
    const userCreatedAt: Date = userRes.rows[0]?.created_at || new Date(0);
    const employeeJoinDateStr = this.getDhakaDateStr(userCreatedAt);

    const targetDate = monthStr ? new Date(`${monthStr}-01`) : new Date();
    const year = targetDate.getFullYear();
    const month = targetDate.getMonth() + 1;

    const daysInMonth = new Date(year, month, 0).getDate();
    const records = await this.getMonthlyRecords(userId, year, month);

    const byDate: Record<string, { morning?: AttendanceRecord; afternoon?: AttendanceRecord }> = {};
    for (const rec of records) {
      const d = rec.date.split('T')[0];
      if (!byDate[d]) byDate[d] = {};
      if (rec.sessionType === 'morning') byDate[d].morning = rec;
      if (rec.sessionType === 'afternoon') byDate[d].afternoon = rec;
    }

    let fullDays = 0;
    let halfDays = 0;
    let weekendOffDays = 0;
    let absences = 0;

    const todayStr = this.getDhakaDateStr();

    for (let day = 1; day <= daysInMonth; day++) {
      const dateObj = new Date(year, month - 1, day);
      const dateStr = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
      const dayOfWeek = dateObj.getDay() === 0 ? 7 : dateObj.getDay();

      if (dateStr > todayStr) {
        continue;
      }

      // Calculation starts from employee creation date; skip prior days
      if (dateStr < employeeJoinDateStr) {
        continue;
      }

      if (weekendDays.includes(dayOfWeek)) {
        weekendOffDays++;
        continue;
      }

      const rec = byDate[dateStr];
      if (!rec) {
        absences++;
      } else if (rec.morning && rec.afternoon) {
        fullDays++;
      } else if (rec.morning || rec.afternoon) {
        halfDays++;
      } else {
        absences++;
      }
    }

    const deductionType = this.officeTimingSettings.deductionType || 'rate_based';
    const fullRate = this.officeTimingSettings.fullDayDeductionAmount ?? 1.0;
    const halfRate = this.officeTimingSettings.halfDayDeductionAmount ?? 0.5;

    let totalDeductionUnits = 0;
    if (deductionType === 'rate_based') {
      totalDeductionUnits = (absences * fullRate) + (halfDays * halfRate);
    } else {
      totalDeductionUnits = (absences * fullRate) + (halfDays * halfRate);
    }

    return {
      userId,
      shiftName: userShift.name,
      year,
      month,
      daysInMonth,
      fullDays,
      halfDays,
      weekendOffDays,
      absences,
      deductionType,
      totalDeductionUnits,
    };
  }

  async overrideAttendance(dto: {
    userIds: string[];
    startDate?: string;
    endDate?: string;
    dates?: string[];
    status?: string;
    sessionType?: string;
    workMode?: string;
    skipWeekends?: boolean;
    skipHolidays?: boolean;
    notes?: string;
    adminId?: string;
    adminName?: string;
    adminRole?: string;
  }) {
    if ((!dto.dates || dto.dates.length === 0) && (!dto.startDate || !dto.endDate)) {
      throw new BadRequestException('Either a date range (startDate, endDate) or a dates array is required.');
    }

    // Resolve date list (YYYY-MM-DD)
    const targetDates: string[] = [];
    if (dto.dates && Array.isArray(dto.dates) && dto.dates.length > 0) {
      for (const d of dto.dates) {
        if (/^\d{4}-\d{2}-\d{2}$/.test(d) && !targetDates.includes(d)) {
          targetDates.push(d);
        }
      }
    } else if (dto.startDate && dto.endDate) {
      const cur = new Date(dto.startDate + 'T00:00:00Z');
      const end = new Date(dto.endDate + 'T00:00:00Z');
      if (isNaN(cur.getTime()) || isNaN(end.getTime()) || cur > end) {
        throw new BadRequestException('Invalid startDate or endDate format/range.');
      }
      while (cur <= end) {
        const yyyy = cur.getUTCFullYear();
        const mm = String(cur.getUTCMonth() + 1).padStart(2, '0');
        const dd = String(cur.getUTCDate()).padStart(2, '0');
        targetDates.push(`${yyyy}-${mm}-${dd}`);
        cur.setUTCDate(cur.getUTCDate() + 1);
      }
    }

    if (targetDates.length === 0) {
      throw new BadRequestException('No valid dates provided for attendance override.');
    }

    // Resolve employees
    let employees: { id: string; full_name: string; email: string }[] = [];
    const isAll = !dto.userIds || dto.userIds.length === 0 || dto.userIds.includes('all');
    if (isAll) {
      const uRes = await this.db.query(
        `SELECT id, full_name, email FROM users WHERE is_active = TRUE AND role NOT IN ('main_admin')`,
      );
      employees = uRes.rows;
    } else {
      const uRes = await this.db.query(
        `SELECT id, full_name, email FROM users WHERE id = ANY($1)`,
        [dto.userIds],
      );
      employees = uRes.rows;
    }

    if (employees.length === 0) {
      throw new BadRequestException('No valid employees found for override.');
    }

    // Fetch official holidays
    let holidaysRes: any = { rows: [] };
    try {
      holidaysRes = await this.db.query(`SELECT date::text AS date, name FROM holidays`);
    } catch (_) {}
    const holidayMap = new Map<string, string>();
    for (const h of holidaysRes.rows) {
      const datePart = (h.date || '').split('T')[0];
      if (datePart) holidayMap.set(datePart, h.name || 'Public Holiday');
    }

    // Timing settings & shifts
    const timingSettings = await this.getTimingSettings();
    const skipWeekends = dto.skipWeekends !== false;
    const skipHolidays = dto.skipHolidays !== false;

    // Normalizing status
    const rawStatus = (dto.status || 'present').toLowerCase().trim();
    let normalizedStatus: string = 'present';
    if (rawStatus === 'late') normalizedStatus = 'late';
    else if (rawStatus === 'half_day' || rawStatus === 'halfday') normalizedStatus = 'half_day';
    else if (rawStatus === 'absent' || rawStatus === 'confirmed_absent') normalizedStatus = 'confirmed_absent';
    else if (rawStatus === 'missing') normalizedStatus = 'missing';

    const workMode = (dto.workMode || 'office').toLowerCase().trim();
    const sessionType = (dto.sessionType || 'all').toLowerCase().trim();
    const sessions = sessionType === 'all' ? ['morning', 'afternoon'] : [sessionType];

    let updatedCount = 0;
    let skippedWeekendsCount = 0;
    let skippedHolidaysCount = 0;
    const adminTag = dto.adminName ? ` by ${dto.adminName}` : '';
    const overrideNote = dto.notes?.trim()
      ? `[Admin Override${adminTag}: ${dto.notes.trim()}]`
      : `[Admin Override${adminTag}]`;

    for (const emp of employees) {
      const shift = this.getShiftForUser(emp.id);
      const shiftWeekend = shift.weekendDays || timingSettings.weekendDays || [5, 6];

      for (const dateStr of targetDates) {
        // Check date day of week (1=Mon..7=Sun)
        const dateObj = new Date(dateStr + 'T12:00:00Z');
        const dayOfWeek = dateObj.getUTCDay() === 0 ? 7 : dateObj.getUTCDay();

        // 1. Off-day / Weekend safeguard
        if (skipWeekends && shiftWeekend.includes(dayOfWeek)) {
          skippedWeekendsCount++;
          continue;
        }

        // 2. Holiday safeguard
        if (skipHolidays && holidayMap.has(dateStr)) {
          skippedHolidaysCount++;
          continue;
        }

        // Upsert records for each session
        for (const session of sessions) {
          const defaultHour = session === 'morning' ? (shift.morningStartHour ?? 9) : (shift.breakEndHour ?? 14);
          const loginTime = `${dateStr}T${String(defaultHour).padStart(2, '0')}:00:00+06:00`;

          await this.db.query(
            `INSERT INTO attendance_records (
               user_id, date, session_type, status, work_mode, notes, login_time, address_text, updated_at
             )
             VALUES ($1, $2, $3, $4, $5, $6, $7, 'Admin Overridden Record', clock_timestamp())
             ON CONFLICT (user_id, date, session_type) DO UPDATE
             SET status = EXCLUDED.status,
                 work_mode = EXCLUDED.work_mode,
                 notes = EXCLUDED.notes,
                 login_time = EXCLUDED.login_time,
                 updated_at = clock_timestamp()`,
            [emp.id, dateStr, session, normalizedStatus, workMode, overrideNote, loginTime],
          );
          updatedCount++;
        }
      }
    }

    // Insert audit log
    try {
      await this.db.query(
        `INSERT INTO audit_logs (user_id, user_name, user_role, action, entity_type, entity_id, details)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [
          dto.adminId || null,
          dto.adminName || 'Administrator',
          dto.adminRole || 'main_admin',
          'ATTENDANCE_OVERRIDE',
          'Attendance',
          'system',
          `Adjusted attendance for ${employees.length} employee(s) over ${targetDates.length} date(s) to status '${normalizedStatus}'. Updated: ${updatedCount}, Skipped Weekends: ${skippedWeekendsCount}, Skipped Holidays: ${skippedHolidaysCount}.`,
        ],
      );
    } catch (_) {}

    return {
      success: true,
      updatedRecords: updatedCount,
      skippedWeekends: skippedWeekendsCount,
      skippedHolidays: skippedHolidaysCount,
      affectedEmployees: employees.length,
      affectedDates: targetDates.length,
      datesRange: `${targetDates[0]} to ${targetDates[targetDates.length - 1]}`,
      statusApplied: normalizedStatus,
    };
  }

  // ==========================================
  // WORK LOCATION ASSIGNMENT SETTINGS
  // ==========================================

  async getAssignedWorkLocation(userId: string, dateStr: string): Promise<{ workLocation: 'office' | 'home' | 'field'; projectId?: string; notes?: string } | null> {
    try {
      const res = await this.db.query(
        `SELECT work_location as "workLocation", project_id as "projectId", notes
         FROM employee_work_locations
         WHERE user_id = $1 AND date = $2
         LIMIT 1`,
        [userId, dateStr],
      );
      if (res.rows.length > 0) {
        return res.rows[0];
      }
    } catch (_) {}
    return null;
  }

  async getWorkLocationAssignments(startDate?: string, endDate?: string, userId?: string) {
    let sql = `SELECT w.id, w.user_id as "userId", u.full_name as "userName", u.email as "userEmail",
                      u.avatar_url as "avatarUrl", COALESCE(u.department, '') as department,
                      w.date::text as "date", w.work_location as "workLocation",
                      w.project_id as "projectId", p.name as "projectName", p.project_code as "projectCode",
                      w.notes, w.created_at as "createdAt"
               FROM employee_work_locations w
               JOIN users u ON w.user_id = u.id
               LEFT JOIN projects p ON w.project_id = p.id
               WHERE 1=1`;
    const params: any[] = [];
    let idx = 1;

    if (startDate) {
      sql += ` AND w.date >= $${idx++}`;
      params.push(startDate);
    }
    if (endDate) {
      sql += ` AND w.date <= $${idx++}`;
      params.push(endDate);
    }
    if (userId) {
      sql += ` AND w.user_id = $${idx++}`;
      params.push(userId);
    }

    sql += ` ORDER BY w.date ASC, u.full_name ASC`;
    const res = await this.db.query(sql, params);
    return res.rows;
  }

  async assignWorkLocations(dto: {
    userIds: string[];
    startDate: string;
    endDate?: string;
    workLocation: 'office' | 'home' | 'field';
    projectId?: string;
    notes?: string;
    adminId?: string;
    adminName?: string;
    adminRole?: string;
  }) {
    if (!dto.userIds || !Array.isArray(dto.userIds) || dto.userIds.length === 0) {
      throw new BadRequestException('Please select at least one employee.');
    }
    if (!dto.startDate || !/^\d{4}-\d{2}-\d{2}$/.test(dto.startDate)) {
      throw new BadRequestException('A valid start date (YYYY-MM-DD) is required.');
    }

    const start = new Date(`${dto.startDate}T00:00:00Z`);
    const endStr = dto.endDate && /^\d{4}-\d{2}-\d{2}$/.test(dto.endDate) ? dto.endDate : dto.startDate;
    const end = new Date(`${endStr}T00:00:00Z`);

    if (end < start) {
      throw new BadRequestException('End date cannot precede start date.');
    }

    const targetDates: string[] = [];
    const cur = new Date(start);
    while (cur <= end) {
      targetDates.push(cur.toISOString().slice(0, 10));
      cur.setUTCDate(cur.getUTCDate() + 1);
    }

    if (targetDates.length > 90) {
      throw new BadRequestException('Cannot assign work locations across more than 90 days at once.');
    }

    const location = (dto.workLocation || 'office').toLowerCase();
    const validLocations = ['office', 'home', 'field'];
    if (!validLocations.includes(location)) {
      throw new BadRequestException(`Invalid work location: ${dto.workLocation}. Must be one of: office, home, field.`);
    }

    let assignedCount = 0;
    for (const userId of dto.userIds) {
      for (const dateStr of targetDates) {
        if (location === 'office' && !dto.notes && !dto.projectId) {
          // Setting back to clean default office deletes specific override row
          await this.db.query(
            `DELETE FROM employee_work_locations WHERE user_id = $1 AND date = $2`,
            [userId, dateStr],
          );
        } else {
          await this.db.query(
            `INSERT INTO employee_work_locations (
               user_id, date, work_location, project_id, notes, assigned_by, updated_at
             )
             VALUES ($1, $2, $3, $4, $5, $6, clock_timestamp())
             ON CONFLICT (user_id, date) DO UPDATE
             SET work_location = EXCLUDED.work_location,
                 project_id = EXCLUDED.project_id,
                 notes = EXCLUDED.notes,
                 assigned_by = EXCLUDED.assigned_by,
                 updated_at = clock_timestamp()`,
            [userId, dateStr, location, dto.projectId || null, dto.notes || null, dto.adminId || null],
          );
        }
        assignedCount++;
      }
    }

    // Audit log
    try {
      await this.db.query(
        `INSERT INTO audit_logs (user_id, user_name, user_role, action, entity_type, entity_id, details)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [
          dto.adminId || null,
          dto.adminName || 'Administrator',
          dto.adminRole || 'main_admin',
          'WORK_LOCATION_ASSIGNED',
          'Attendance',
          'system',
          `Assigned work location '${location}' for ${dto.userIds.length} employee(s) across ${targetDates.length} date(s) (${targetDates[0]} to ${targetDates[targetDates.length - 1]}). Notes: ${dto.notes || 'None'}.`,
        ],
      );
    } catch (_) {}

    return {
      success: true,
      workLocation: location,
      assignedCount,
      employeesCount: dto.userIds.length,
      datesCount: targetDates.length,
      datesRange: `${targetDates[0]} to ${targetDates[targetDates.length - 1]}`,
      message: `Work location successfully set to ${location.toUpperCase()} for ${dto.userIds.length} employee(s).`,
    };
  }

  async deleteWorkLocationAssignment(id: string) {
    await this.db.query(`DELETE FROM employee_work_locations WHERE id = $1`, [id]);
    return { success: true, message: 'Work location assignment removed, reverted to default Office.' };
  }
}
