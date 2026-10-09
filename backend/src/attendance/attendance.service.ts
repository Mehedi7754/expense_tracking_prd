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
  status: string;
  notes: string;
  createdAt: string;
}

export interface ShiftDefinition {
  id: string;
  name: string;
  morningStartHour: number;
  morningEndHour: number;
  afternoonStartHour: number;
  afternoonEndHour: number;
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

  private officeTimingSettings = {
    morningStartHour: 9,
    morningEndHour: 13,
    afternoonStartHour: 13,
    afternoonEndHour: 18,
    weekendDays: [5, 6],
    deductionType: 'rate_based',
    fullDayDeductionAmount: 1.0,
    halfDayDeductionAmount: 0.5,
    gracePeriodMinutes: 15,
    shifts: [
      {
        id: 'shift_default',
        name: 'General Office Shift',
        morningStartHour: 9,
        morningEndHour: 13,
        afternoonStartHour: 13,
        afternoonEndHour: 18,
        weekendDays: [5, 6],
        isDefault: true,
      },
      {
        id: 'shift_morning',
        name: 'Early Morning Shift',
        morningStartHour: 7,
        morningEndHour: 11,
        afternoonStartHour: 11,
        afternoonEndHour: 15,
        weekendDays: [5, 6],
        isDefault: false,
      },
      {
        id: 'shift_evening',
        name: 'Evening Shift',
        morningStartHour: 14,
        morningEndHour: 18,
        afternoonStartHour: 18,
        afternoonEndHour: 22,
        weekendDays: [7],
        isDefault: false,
      },
    ] as ShiftDefinition[],
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
      if (settings.morningEndHour !== undefined && !settings.shifts) {
        defaultShift.morningEndHour = settings.morningEndHour;
        defaultShift.afternoonStartHour = settings.morningEndHour;
      } else if (settings.shifts && defaultShift) {
        this.officeTimingSettings.morningStartHour = defaultShift.morningStartHour;
        this.officeTimingSettings.morningEndHour = defaultShift.morningEndHour;
        this.officeTimingSettings.afternoonStartHour = defaultShift.afternoonStartHour;
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
      morningEndHour: 13,
      afternoonStartHour: 13,
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

    // 2. Resolve local office hour (Bangladesh Standard Time: UTC+6) and assigned user shift
    const dhakaNow = new Date(new Date().toLocaleString('en-US', { timeZone: 'Asia/Dhaka' }));
    const currentHour = dhakaNow.getHours();
    const userShift = this.getShiftForUser(userId);

    const morningStart = userShift.morningStartHour ?? 9;
    const morningEnd = userShift.morningEndHour ?? 13;
    const afternoonStart = userShift.afternoonStartHour ?? userShift.morningEndHour ?? 13;
    const afternoonEnd = userShift.afternoonEndHour ?? 18;

    let session: 'morning' | 'afternoon';
    const explicit = (dto.sessionType || dto.session_type || '').toLowerCase();
    if (explicit === 'morning') {
      session = 'morning';
    } else if (explicit === 'afternoon') {
      session = 'afternoon';
    } else {
      const divider = userShift.morningEndHour ?? 13;
      session = currentHour < divider ? 'morning' : 'afternoon';
    }

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
      throw new ConflictException(`You have already checked in for the ${session} session today.`);
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

    try {
      const userRes = await this.db.query('SELECT full_name, email, avatar_url FROM users WHERE id = $1', [userId]);
      const empName = userRes.rows[0]?.full_name || 'Team member';
      const empEmail = userRes.rows[0]?.email || '';
      const empAvatar = userRes.rows[0]?.avatar_url || null;
      const timeStr = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
      
      // Calculate Late Status based on configurable grace period
      const currentMinute = dhakaNow.getMinutes();
      const gracePeriod = this.officeTimingSettings.gracePeriodMinutes ?? 15;
      let isLate = false;
      if (session === 'morning') {
        if (currentHour > morningStart || (currentHour === morningStart && currentMinute > gracePeriod)) {
          isLate = true;
        }
      } else {
        // Evening / afternoon check-out can be done at any time when employee leaves
        isLate = false;
      }

      const statusTag = isLate ? '⚠️ LATE' : '✅ ON TIME';
      const isCheckOut = session === 'afternoon';

      // Notify employee with attendance confirmation
      await this.notificationsService.create({
        userId,
        title: isCheckOut ? 'Attendance Check-Out 📍' : 'Attendance Recorded 📍',
        message: isCheckOut
          ? `Your check-out was successfully recorded at ${timeStr}.`
          : `Your check-in for the ${session} session was successfully recorded at ${timeStr}.`,
        fullExplanation: isCheckOut
          ? `Attendance check-out verified at ${timeStr}. Shift: ${userShift.name}. GPS Location: [${dto.latitude ?? 'N/A'}, ${dto.longitude ?? 'N/A'}]. Address: ${address || 'Office Premises'}. Status: Checked Out.`
          : `Attendance check-in verified at ${timeStr}. Shift: ${userShift.name}. GPS Location: [${dto.latitude ?? 'N/A'}, ${dto.longitude ?? 'N/A'}]. Address: ${address || 'Office Premises'}. Status: Present.`,
        type: isLate ? 'attendance_late' : 'attendance_reminder',
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
          isLate
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
            ? `Employee Checked Out: ${empName}`
            : `Employee Checked In: ${statusTag}`,
          message: isCheckOut
            ? `${empName} checked out at ${timeStr}.`
            : `${empName} recorded attendance for ${session} session at ${timeStr}.`,
          fullExplanation: isCheckOut
            ? `${empName} checked out on ${new Date().toLocaleDateString()} at ${timeStr}. Location coordinates: [${dto.latitude ?? 'N/A'}, ${dto.longitude ?? 'N/A'}]. Address: ${address || 'Office Premises'}.`
            : `${empName} logged in for the ${session} session on ${new Date().toLocaleDateString()} at ${timeStr}. Location coordinates: [${dto.latitude ?? 'N/A'}, ${dto.longitude ?? 'N/A'}]. Address: ${address || 'Office Premises'}.`,
          type: isLate ? 'attendance_late' : 'attendance_reminder',
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
              a.status, a.notes, a.created_at::text as "createdAt"
       FROM attendance_records a
       JOIN users u ON a.user_id = u.id
       WHERE a.id = $1`,
      [id],
    );
    return res.rows[0] || null;
  }

  async getTodayRecords(): Promise<AttendanceRecord[]> {
    const res = await this.db.query(
      `SELECT a.id, a.user_id as "userId", u.full_name as "userName", u.email as "userEmail",
              COALESCE(u.department, '') as department, COALESCE(u.designation, '') as designation,
              u.avatar_url as "avatarUrl", a.date::text, a.session_type as "sessionType",
              a.login_time::text as "loginTime", a.latitude, a.longitude,
              a.address_text as "addressText", a.device_info as "deviceInfo",
              a.status, a.notes, a.created_at::text as "createdAt"
       FROM attendance_records a
       JOIN users u ON a.user_id = u.id
       WHERE a.date = CURRENT_DATE AND u.is_active = TRUE
       ORDER BY a.login_time DESC`,
    );
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
              a.status, a.notes, a.created_at::text as "createdAt"
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
              a.status, a.notes, a.created_at::text as "createdAt"
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
    const targetDate = dateStr || new Date().toISOString().split('T')[0];
    const targetDateObj = new Date(targetDate.includes('T') ? targetDate : `${targetDate}T00:00:00Z`);
    const dayOfWeek = targetDateObj.getUTCDay() === 0 ? 7 : targetDateObj.getUTCDay();

    // Query all active non-exempt users
    const usersRes = await this.db.query(
      `SELECT id, full_name as "userName", email as "userEmail", role,
              COALESCE(department, '') as department, COALESCE(designation, '') as designation,
              avatar_url as "avatarUrl"
       FROM users
       WHERE is_active = TRUE AND role NOT IN ('main_admin', 'finance')
       ORDER BY full_name ASC`,
    );

    const recordsRes = await this.db.query(
      `SELECT a.id, a.user_id as "userId", u.full_name as "userName", u.email as "userEmail",
              COALESCE(u.department, '') as department, COALESCE(u.designation, '') as designation,
              u.avatar_url as "avatarUrl", a.date::text, a.session_type as "sessionType",
              a.login_time::text as "loginTime", a.latitude, a.longitude,
              a.address_text as "addressText", a.device_info as "deviceInfo",
              a.status, a.notes, a.created_at::text as "createdAt"
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

    const employees = usersRes.rows.map((user: any) => {
      const shift = this.getShiftForUser(user.id);
      const shiftWeekends = shift?.weekendDays || this.officeTimingSettings.weekendDays || [5, 6];
      const isWeekend = shiftWeekends.includes(dayOfWeek);
      const rec = byUser[user.id];

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
    let whereClause = `WHERE date = CURRENT_DATE`;
    const params: any[] = [];

    if (userId) {
      params.push(userId);
      whereClause += ` AND user_id = $1`;
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
      date: new Date().toISOString().split('T')[0],
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

    const todayStr = new Date().toISOString().split('T')[0];

    for (let day = 1; day <= daysInMonth; day++) {
      const dateObj = new Date(year, month - 1, day);
      const dateStr = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
      const dayOfWeek = dateObj.getDay() === 0 ? 7 : dateObj.getDay();

      if (dateStr > todayStr) {
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
}
