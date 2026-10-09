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

  getDhakaDateStr(date?: Date): string {
    const d = date || new Date();
    const dhakaDate = new Date(d.toLocaleString('en-US', { timeZone: 'Asia/Dhaka' }));
    const yyyy = dhakaDate.getFullYear();
    const mm = String(dhakaDate.getMonth() + 1).padStart(2, '0');
    const dd = String(dhakaDate.getDate()).padStart(2, '0');
    return `${yyyy}-${mm}-${dd}`;
  }

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

    const currentMinute = dhakaNow.getMinutes();
    const gracePeriod = this.officeTimingSettings.gracePeriodMinutes ?? 15;
    const isCheckOut = session === 'afternoon';

    let isLate = false;
    if (session === 'morning') {
      if (currentHour > morningStart || (currentHour === morningStart && currentMinute > gracePeriod)) {
        isLate = true;
      }
    }

    const currentTotalMinutes = currentHour * 60 + currentMinute;
    const afternoonEndMinutes = afternoonEnd * 60;
    const isEarly = isCheckOut && (currentTotalMinutes < (afternoonEndMinutes - gracePeriod));

    const address = dto.addressText || dto.address_text || '';
    const deviceInfo = dto.deviceInfo || '';
    let notes = dto.notes || '';
    if (isEarly) {
      notes = notes ? `${notes} [Checked out before time]` : '[Checked out before time]';
    } else if (isLate) {
      notes = notes ? `${notes} [Late check-in]` : '[Late check-in]';
    }

    const targetDate = dto.date && /^\d{4}-\d{2}-\d{2}$/.test(dto.date) ? dto.date : this.getDhakaDateStr(dhakaNow);

    // Check if record exists for this user, date and session
    const existing = await this.db.query(
      `SELECT id FROM attendance_records
       WHERE user_id = $1 AND date = $2 AND session_type = $3`,
      [userId, targetDate, session],
    );

    let recordId: string;

    if (existing.rows.length > 0) {
      throw new ConflictException(`You have already checked in for the ${session} session on ${targetDate}.`);
    } else {
      const res = await this.db.query(
        `INSERT INTO attendance_records (user_id, date, session_type, login_time, latitude, longitude, address_text, device_info, status, notes)
         VALUES ($1, $2, $3, clock_timestamp(), $4, $5, $6, $7, 'present', $8)
         RETURNING id`,
        [userId, targetDate, session, dto.latitude, dto.longitude, address, deviceInfo, notes],
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
      const timeStr = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
      
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
            ? `${empName} checked out on ${new Date().toLocaleDateString()} at ${timeStr}. Shift: ${userShift.name} (Scheduled end: ${afternoonEnd}:00, ${isEarly ? 'Early departure' : 'On time'}). Location coordinates: [${dto.latitude ?? 'N/A'}, ${dto.longitude ?? 'N/A'}]. Address: ${address || 'Office Premises'}.`
            : `${empName} logged in for the ${session} session on ${new Date().toLocaleDateString()} at ${timeStr}. Location coordinates: [${dto.latitude ?? 'N/A'}, ${dto.longitude ?? 'N/A'}]. Address: ${address || 'Office Premises'}.`,
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
              a.status, a.notes, a.created_at::text as "createdAt"
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
                      a.status, a.notes, a.created_at::text as "createdAt"
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
}
