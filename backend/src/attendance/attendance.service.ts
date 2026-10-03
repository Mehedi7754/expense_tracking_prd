import { Injectable, Logger, BadRequestException, ForbiddenException } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { CheckInDto } from './dto/check-in.dto';

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
  status: string;
  notes: string;
  createdAt: string;
}

@Injectable()
export class AttendanceService {
  private readonly logger = new Logger(AttendanceService.name);

  constructor(private readonly db: DatabaseService) {}

  private officeTimingSettings = {
    morningStartHour: 9,
    morningEndHour: 13,
    afternoonStartHour: 13,
    afternoonEndHour: 18,
    weekendDays: [5, 6],
    deductionType: 'rate_based',
    fullDayDeductionAmount: 1.0,
    halfDayDeductionAmount: 0.5,
    shifts: [
      {
        id: 'shift_default',
        name: 'General Office Shift',
        morningStartHour: 9,
        morningEndHour: 13,
        afternoonStartHour: 13,
        afternoonEndHour: 18,
        isDefault: true,
      },
      {
        id: 'shift_morning',
        name: 'Early Morning Shift',
        morningStartHour: 7,
        morningEndHour: 11,
        afternoonStartHour: 11,
        afternoonEndHour: 15,
        isDefault: false,
      },
      {
        id: 'shift_evening',
        name: 'Evening Shift',
        morningStartHour: 14,
        morningEndHour: 18,
        afternoonStartHour: 18,
        afternoonEndHour: 22,
        isDefault: false,
      },
    ],
    userShifts: {} as Record<string, string>,
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
    this.officeTimingSettings = {
      ...this.officeTimingSettings,
      ...settings,
      afternoonStartHour: settings.morningEndHour !== undefined ? settings.morningEndHour : this.officeTimingSettings.afternoonStartHour,
    };
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
    }
    return this.officeTimingSettings;
  }

  /**
   * Determine session based on configured office timing if not provided:
   * Morning: 00:00 - morningEndHour
   * Afternoon: morningEndHour - 23:59
   */
  private resolveSessionType(explicitSession?: 'morning' | 'afternoon'): 'morning' | 'afternoon' {
    if (explicitSession === 'morning' || explicitSession === 'afternoon') {
      return explicitSession;
    }
    const currentHour = new Date().getHours();
    return currentHour < this.officeTimingSettings.morningEndHour ? 'morning' : 'afternoon';
  }

  async checkIn(userId: string, dto: CheckInDto): Promise<AttendanceRecord> {
    const session = this.resolveSessionType(dto.sessionType || dto.session_type);
    const address = dto.addressText || dto.address_text || '';
    const deviceInfo = dto.deviceInfo || '';
    const notes = dto.notes || '';

    // Check if record exists for this user, date and session
    const existing = await this.db.query(
      `SELECT id FROM attendance_records
       WHERE user_id = $1 AND date = CURRENT_DATE AND session_type = $2`,
      [userId, session],
    );

    let recordId: string;

    if (existing.rows.length > 0) {
      recordId = existing.rows[0].id;
      // Update check-in record
      await this.db.query(
        `UPDATE attendance_records
         SET login_time = clock_timestamp(),
             latitude = $1,
             longitude = $2,
             address_text = COALESCE(NULLIF($3, ''), address_text),
             device_info = COALESCE(NULLIF($4, ''), device_info),
             notes = COALESCE(NULLIF($5, ''), notes),
             updated_at = clock_timestamp()
         WHERE id = $6`,
        [dto.latitude, dto.longitude, address, deviceInfo, notes, recordId],
      );
      this.logger.log(`Updated attendance check-in for user ${userId} (${session}) at [${dto.latitude}, ${dto.longitude}]`);
    } else {
      const res = await this.db.query(
        `INSERT INTO attendance_records (user_id, date, session_type, login_time, latitude, longitude, address_text, device_info, status, notes)
         VALUES ($1, CURRENT_DATE, $2, clock_timestamp(), $3, $4, $5, $6, 'present', $7)
         RETURNING id`,
        [userId, session, dto.latitude, dto.longitude, address, deviceInfo, notes],
      );
      recordId = res.rows[0].id;
      this.logger.log(`Created new attendance check-in for user ${userId} (${session}) at [${dto.latitude}, ${dto.longitude}]`);
    }

    const fetched = await this.getRecordById(recordId);
    if (!fetched) {
      throw new BadRequestException('Failed to retrieve recorded attendance');
    }
    return fetched;
  }

  async getRecordById(id: string): Promise<AttendanceRecord | null> {
    const res = await this.db.query(
      `SELECT a.id, a.user_id, a.date::text, a.session_type, a.login_time,
              a.latitude, a.longitude, a.address_text, a.device_info, a.status,
              a.notes, a.created_at,
              u.full_name, u.email, u.department, u.designation, u.avatar_url
       FROM attendance_records a
       JOIN users u ON u.id = a.user_id
       WHERE a.id = $1`,
      [id],
    );
    if (!res.rows.length) return null;
    return this.mapRow(res.rows[0]);
  }

  async getAttendanceRecords(params: {
    userId?: string;
    date?: string;
    month?: number;
    year?: number;
    sessionType?: string;
    currentUserRole: string;
    currentUserId: string;
  }): Promise<AttendanceRecord[]> {
    const { userId, date, month, year, sessionType, currentUserRole, currentUserId } = params;

    const normalizedRole = (currentUserRole || '').toLowerCase().replace(/_/g, '');
    const isPrivileged = [
      'mainadmin',
      'admin',
      'projectmanager',
      'manager',
      'financemanager',
      'finance',
    ].includes(normalizedRole);

    const conditions: string[] = [];
    const values: any[] = [];
    let idx = 1;

    // RBAC: Non-admin/manager can only see their own attendance
    if (!isPrivileged) {
      conditions.push(`a.user_id = $${idx++}`);
      values.push(currentUserId);
    } else if (userId) {
      conditions.push(`a.user_id = $${idx++}`);
      values.push(userId);
    }

    if (date) {
      conditions.push(`a.date = $${idx++}`);
      values.push(date);
    }

    if (month && year) {
      conditions.push(`EXTRACT(MONTH FROM a.date) = $${idx++}`);
      values.push(month);
      conditions.push(`EXTRACT(YEAR FROM a.date) = $${idx++}`);
      values.push(year);
    } else if (year) {
      conditions.push(`EXTRACT(YEAR FROM a.date) = $${idx++}`);
      values.push(year);
    }

    if (sessionType) {
      conditions.push(`a.session_type = $${idx++}`);
      values.push(sessionType);
    }

    const whereClause = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

    const sql = `
      SELECT a.id, a.user_id, a.date::text, a.session_type, a.login_time,
             a.latitude, a.longitude, a.address_text, a.device_info, a.status,
             a.notes, a.created_at,
             u.full_name, u.email, u.department, u.designation, u.avatar_url
      FROM attendance_records a
      JOIN users u ON u.id = a.user_id
      ${whereClause}
      ORDER BY a.date DESC, a.login_time DESC
    `;

    const res = await this.db.query(sql, values);
    return res.rows.map((row) => this.mapRow(row));
  }

  async getAttendanceSummary(userId: string, month: number, year: number) {
    const res = await this.db.query(
      `SELECT a.date::text, a.session_type, a.status, a.login_time, a.latitude, a.longitude, a.address_text
       FROM attendance_records a
       WHERE a.user_id = $1
         AND EXTRACT(MONTH FROM a.date) = $2
         AND EXTRACT(YEAR FROM a.date) = $3
       ORDER BY a.date ASC, a.session_type ASC`,
      [userId, month, year],
    );

    const dailySessionsMap: { [date: string]: { morning?: any; afternoon?: any } } = {};
    for (const row of res.rows) {
      if (!dailySessionsMap[row.date]) {
        dailySessionsMap[row.date] = {};
      }
      if (row.session_type === 'morning') {
        dailySessionsMap[row.date].morning = row;
      } else {
        dailySessionsMap[row.date].afternoon = row;
      }
    }

    let fullPresentDays = 0;
    let halfDays = 0;

    for (const date in dailySessionsMap) {
      const entry = dailySessionsMap[date];
      if (entry.morning && entry.afternoon) {
        fullPresentDays++;
      } else if (entry.morning || entry.afternoon) {
        halfDays++;
      }
    }

    const totalPresentEquivalent = fullPresentDays + halfDays * 0.5;

    return {
      userId,
      month,
      year,
      totalRecords: res.rows.length,
      fullPresentDays,
      halfDays,
      totalPresentEquivalent,
      dailySessions: dailySessionsMap,
    };
  }

  async getDailyOverview(date: string) {
    const targetDate = date || new Date().toISOString().split('T')[0];

    // Fetch all active employees
    const usersRes = await this.db.query(
      `SELECT id, full_name, email, department, designation, avatar_url, role
       FROM users
       WHERE is_active = TRUE
       ORDER BY department ASC, full_name ASC`,
    );

    // Fetch all attendance records for targetDate
    const attRes = await this.db.query(
      `SELECT a.id, a.user_id, a.session_type, a.login_time, a.latitude, a.longitude,
              a.address_text, a.status, a.notes
       FROM attendance_records a
       WHERE a.date = $1`,
      [targetDate],
    );

    const attMap: { [userId: string]: { morning?: any; afternoon?: any } } = {};
    for (const att of attRes.rows) {
      if (!attMap[att.user_id]) attMap[att.user_id] = {};
      if (att.session_type === 'morning') {
        attMap[att.user_id].morning = att;
      } else {
        attMap[att.user_id].afternoon = att;
      }
    }

    // Query holidays covering targetDate
    const holidayRes = await this.db.query(
      `SELECT name FROM holidays WHERE date = $1 LIMIT 1`,
      [targetDate],
    );
    const holidayName = holidayRes.rows.length ? holidayRes.rows[0].name : null;

    // Check weekend against configured off-days (1=Mon, 2=Tue, ... 5=Fri, 6=Sat, 7=Sun)
    const targetDateObj = new Date(targetDate + 'T00:00:00Z');
    const dayOfWeek = targetDateObj.getUTCDay();
    const dartWeekday = dayOfWeek === 0 ? 7 : dayOfWeek;
    const configuredWeekendDays = this.officeTimingSettings.weekendDays || [5, 6];
    const isWeekend = configuredWeekendDays.includes(dartWeekday);

    const employees = usersRes.rows.map((user) => {
      const userAtt = attMap[user.id] || {};
      let status = 'missing';
      if (userAtt.morning && userAtt.afternoon) {
        status = 'present';
      } else if (userAtt.morning || userAtt.afternoon) {
        status = 'half_day';
      } else if (holidayName) {
        status = 'holiday';
      } else if (isWeekend) {
        status = 'weekend';
      }

      return {
        userId: user.id,
        userName: user.full_name,
        userEmail: user.email,
        department: user.department,
        designation: user.designation,
        role: user.role,
        avatarUrl: user.avatar_url,
        date: targetDate,
        status,
        morning: userAtt.morning || null,
        afternoon: userAtt.afternoon || null,
      };
    });

    const presentCount = employees.filter((e) => e.status === 'present').length;
    const halfDayCount = employees.filter((e) => e.status === 'half_day').length;
    const missingCount = employees.filter((e) => e.status === 'missing').length;

    return {
      date: targetDate,
      isWeekend,
      holidayName,
      totalEmployees: employees.length,
      presentCount,
      halfDayCount,
      missingCount,
      employees,
    };
  }

  async confirmAbsence(userId: string, date: string, notes?: string, adminUserId?: string) {
    // Inserts or marks record as confirmed_absent for morning and afternoon
    await this.db.query(
      `INSERT INTO attendance_records (user_id, date, session_type, status, notes, login_time)
       VALUES ($1, $2, 'morning', 'confirmed_absent', $3, clock_timestamp())
       ON CONFLICT (user_id, date, session_type)
       DO UPDATE SET status = 'confirmed_absent', notes = EXCLUDED.notes, updated_at = clock_timestamp()`,
      [userId, date, notes || 'Confirmed absent by administrator'],
    );

    await this.db.query(
      `INSERT INTO attendance_records (user_id, date, session_type, status, notes, login_time)
       VALUES ($1, $2, 'afternoon', 'confirmed_absent', $3, clock_timestamp())
       ON CONFLICT (user_id, date, session_type)
       DO UPDATE SET status = 'confirmed_absent', notes = EXCLUDED.notes, updated_at = clock_timestamp()`,
      [userId, date, notes || 'Confirmed absent by administrator'],
    );

    return { success: true, message: `Absence confirmed for user on ${date}` };
  }

  private mapRow(row: any): AttendanceRecord {
    return {
      id: row.id,
      userId: row.user_id,
      userName: row.full_name || '',
      userEmail: row.email || '',
      department: row.department || '',
      designation: row.designation || '',
      avatarUrl: row.avatar_url || '',
      date: row.date,
      sessionType: row.session_type,
      loginTime: row.login_time ? new Date(row.login_time).toISOString() : '',
      latitude: row.latitude ? parseFloat(row.latitude) : null,
      longitude: row.longitude ? parseFloat(row.longitude) : null,
      addressText: row.address_text || '',
      deviceInfo: row.device_info || '',
      status: row.status || 'present',
      notes: row.notes || '',
      createdAt: row.created_at ? new Date(row.created_at).toISOString() : '',
    };
  }
}
