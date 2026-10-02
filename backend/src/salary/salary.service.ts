import { Injectable, Logger, NotFoundException, BadRequestException } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { SetSalaryDto } from './dto/set-salary.dto';
import { CreateHolidayDto } from './dto/holiday.dto';
import { CreateLeaveDto } from './dto/leave.dto';
import { CreateAdjustmentDto } from './dto/adjustment.dto';

export interface DailyBreakdownItem {
  date: string;
  dayOfWeek: string;
  isWeekend: boolean;
  isHoliday: boolean;
  holidayName?: string;
  isLeave: boolean;
  leaveType?: string;
  isPaidLeave: boolean;
  isFuture: boolean;
  morningAttended: boolean;
  morningTime?: string;
  morningLocation?: { lat: number; lng: number; address: string };
  afternoonAttended: boolean;
  afternoonTime?: string;
  afternoonLocation?: { lat: number; lng: number; address: string };
  status: 'present' | 'half_day' | 'missing_record' | 'confirmed_absent' | 'paid_leave' | 'unpaid_leave' | 'holiday' | 'weekend' | 'upcoming';
  presentWeight: number; // 1.0, 0.5, or 0.0
  deductionUnits: number; // 0.0, 0.5, or 1.0
  notes: string;
}

export interface SalaryCalculationResult {
  userId: string;
  userName: string;
  userEmail: string;
  department: string;
  designation: string;
  avatarUrl?: string;
  month: number;
  year: number;
  monthlyBaseSalary: number;
  currency: string;
  calendarDaysInMonth: number;
  weekendDays: number;
  holidayDays: number;
  scheduledWorkingDays: number;
  configuredPayableWorkingDays: number;
  dailySalaryRate: number;
  presentDays: number;
  halfDays: number;
  paidLeaveDays: number;
  unpaidLeaveDays: number;
  missingLoginDays: number;
  confirmedAbsentDays: number;
  totalAbsenceDeductions: number;
  totalAdditions: number;
  totalPenalties: number;
  finalPayableSalary: number;
  isConfirmed: boolean;
  dailyBreakdown: DailyBreakdownItem[];
}

@Injectable()
export class SalaryService {
  private readonly logger = new Logger(SalaryService.name);

  constructor(private readonly db: DatabaseService) {}

  /**
   * Fetch employee base salary profile. Creates default if not set yet.
   */
  async getEmployeeSalary(userId: string) {
    const res = await this.db.query(
      `SELECT s.id, s.user_id, s.monthly_salary, s.currency, s.standard_working_days,
              s.effective_from::text, s.effective_to::text,
              u.full_name, u.email, u.department, u.designation
       FROM employee_salaries s
       JOIN users u ON u.id = s.user_id
       WHERE s.user_id = $1`,
      [userId],
    );

    if (res.rows.length) {
      const row = res.rows[0];
      return {
        id: row.id,
        userId: row.user_id,
        userName: row.full_name,
        userEmail: row.email,
        department: row.department,
        designation: row.designation,
        monthlySalary: parseFloat(row.monthly_salary),
        currency: row.currency || 'BDT',
        standardWorkingDays: parseInt(row.standard_working_days, 10) || 22,
        effectiveFrom: row.effective_from,
        effectiveTo: row.effective_to,
      };
    }

    // Check if user exists
    const userRes = await this.db.query('SELECT full_name, email, department, designation FROM users WHERE id = $1', [userId]);
    if (!userRes.rows.length) {
      throw new NotFoundException(`User with ID ${userId} not found`);
    }

    // Default salary of 50000 BDT, 22 working days
    const insertRes = await this.db.query(
      `INSERT INTO employee_salaries (user_id, monthly_salary, currency, standard_working_days)
       VALUES ($1, 50000.00, 'BDT', 22)
       RETURNING id, user_id, monthly_salary, currency, standard_working_days, effective_from::text`,
      [userId],
    );

    const row = insertRes.rows[0];
    const u = userRes.rows[0];
    return {
      id: row.id,
      userId: row.user_id,
      userName: u.full_name,
      userEmail: u.email,
      department: u.department,
      designation: u.designation,
      monthlySalary: parseFloat(row.monthly_salary),
      currency: row.currency,
      standardWorkingDays: parseInt(row.standard_working_days, 10),
      effectiveFrom: row.effective_from,
      effectiveTo: null,
    };
  }

  async setEmployeeSalary(userId: string, dto: SetSalaryDto, adminId?: string) {
    const existing = await this.db.query('SELECT id FROM employee_salaries WHERE user_id = $1', [userId]);

    const workingDays = dto.standardWorkingDays && dto.standardWorkingDays > 0 ? dto.standardWorkingDays : 22;
    const currency = dto.currency || 'BDT';

    if (existing.rows.length) {
      await this.db.query(
        `UPDATE employee_salaries
         SET monthly_salary = $1,
             currency = $2,
             standard_working_days = $3,
             effective_from = COALESCE($4, effective_from),
             updated_at = clock_timestamp()
         WHERE user_id = $5`,
        [dto.monthlySalary, currency, workingDays, dto.effectiveFrom || null, userId],
      );
    } else {
      await this.db.query(
        `INSERT INTO employee_salaries (user_id, monthly_salary, currency, standard_working_days, created_by)
         VALUES ($1, $2, $3, $4, $5)`,
        [userId, dto.monthlySalary, currency, workingDays, adminId || null],
      );
    }

    return this.getEmployeeSalary(userId);
  }

  // --- Holidays ---
  async getHolidays(year?: number) {
    let sql = 'SELECT id, date::text, name, is_recurring FROM holidays';
    const params: any[] = [];
    if (year) {
      sql += ' WHERE EXTRACT(YEAR FROM date) = $1 OR is_recurring = TRUE';
      params.push(year);
    }
    sql += ' ORDER BY date ASC';
    const res = await this.db.query(sql, params);
    return res.rows.map((r) => ({
      id: r.id,
      date: r.date,
      name: r.name,
      isRecurring: r.is_recurring,
    }));
  }

  async addHoliday(dto: CreateHolidayDto, adminId?: string) {
    const res = await this.db.query(
      `INSERT INTO holidays (date, name, is_recurring, created_by)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (date) DO UPDATE SET name = EXCLUDED.name, is_recurring = EXCLUDED.is_recurring
       RETURNING id, date::text, name, is_recurring`,
      [dto.date, dto.name, dto.isRecurring ?? false, adminId || null],
    );
    return res.rows[0];
  }

  async deleteHoliday(id: string) {
    await this.db.query('DELETE FROM holidays WHERE id = $1', [id]);
    return { success: true };
  }

  // --- Leaves ---
  async getLeaves(userId?: string, month?: number, year?: number) {
    let sql = `
      SELECT l.id, l.user_id, l.start_date::text, l.end_date::text, l.leave_type,
             l.reason, l.is_approved, u.full_name, u.email
      FROM leave_records l
      JOIN users u ON u.id = l.user_id
    `;
    const conds: string[] = [];
    const params: any[] = [];
    let idx = 1;

    if (userId) {
      conds.push(`l.user_id = $${idx++}`);
      params.push(userId);
    }
    if (year && month) {
      conds.push(`(
        (EXTRACT(YEAR FROM l.start_date) = $${idx} AND EXTRACT(MONTH FROM l.start_date) = $${idx + 1})
        OR
        (EXTRACT(YEAR FROM l.end_date) = $${idx} AND EXTRACT(MONTH FROM l.end_date) = $${idx + 1})
      )`);
      params.push(year, month);
      idx += 2;
    }

    if (conds.length) {
      sql += ' WHERE ' + conds.join(' AND ');
    }
    sql += ' ORDER BY l.start_date DESC';

    const res = await this.db.query(sql, params);
    return res.rows.map((r) => ({
      id: r.id,
      userId: r.user_id,
      userName: r.full_name,
      userEmail: r.email,
      startDate: r.start_date,
      endDate: r.end_date,
      leaveType: r.leave_type,
      reason: r.reason,
      isApproved: r.is_approved,
    }));
  }

  async addLeave(dto: CreateLeaveDto, approvedBy?: string) {
    const res = await this.db.query(
      `INSERT INTO leave_records (user_id, start_date, end_date, leave_type, reason, is_approved, approved_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING id, user_id, start_date::text, end_date::text, leave_type, reason, is_approved`,
      [dto.userId, dto.startDate, dto.endDate, dto.leaveType, dto.reason || '', dto.isApproved ?? true, approvedBy || null],
    );
    return res.rows[0];
  }

  async deleteLeave(id: string) {
    await this.db.query('DELETE FROM leave_records WHERE id = $1', [id]);
    return { success: true };
  }

  // --- Adjustments ---
  async getAdjustments(userId: string, month?: number, year?: number) {
    let sql = 'SELECT id, user_id, adjustment_type, amount, reason, created_at FROM salary_adjustments WHERE user_id = $1';
    const params: any[] = [userId];
    if (month && year) {
      sql += ' AND EXTRACT(MONTH FROM created_at) = $2 AND EXTRACT(YEAR FROM created_at) = $3';
      params.push(month, year);
    }
    sql += ' ORDER BY created_at DESC';
    const res = await this.db.query(sql, params);
    return res.rows.map((r) => ({
      id: r.id,
      userId: r.user_id,
      adjustmentType: r.adjustment_type,
      amount: parseFloat(r.amount),
      reason: r.reason,
      createdAt: r.created_at,
    }));
  }

  async addAdjustment(dto: CreateAdjustmentDto, adminId?: string) {
    const res = await this.db.query(
      `INSERT INTO salary_adjustments (user_id, adjustment_type, amount, reason, adjusted_by)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, user_id, adjustment_type, amount, reason, created_at`,
      [dto.userId, dto.adjustmentType, dto.amount, dto.reason, adminId || null],
    );
    return res.rows[0];
  }

  /**
   * Main calculation engine:
   * Daily Salary Rate = Monthly Salary ÷ Configured Payable Working Days
   * Final Payable Salary = Monthly Salary − Total Unpaid Absence Deductions (+ additions)
   */
  async calculateSalary(userId: string, month: number, year: number): Promise<SalaryCalculationResult> {
    const salaryProfile = await this.getEmployeeSalary(userId);

    // Get all calendar days in given month
    const daysInMonth = new Date(year, month, 0).getDate();
    const today = new Date();
    const todayIso = today.toISOString().split('T')[0];

    // Fetch holidays in this month
    const holidays = await this.getHolidays(year);
    const holidayMap = new Map<string, string>();
    for (const h of holidays) {
      holidayMap.set(h.date, h.name);
    }

    // Fetch approved leaves covering any day in this month
    const leaves = await this.getLeaves(userId, month, year);

    // Fetch attendance records for this user in this month
    const attRes = await this.db.query(
      `SELECT id, date::text, session_type, login_time, latitude, longitude, address_text, status, notes
       FROM attendance_records
       WHERE user_id = $1
         AND EXTRACT(MONTH FROM date) = $2
         AND EXTRACT(YEAR FROM date) = $3`,
      [userId, month, year],
    );

    const attMap: { [date: string]: { morning?: any; afternoon?: any } } = {};
    for (const row of attRes.rows) {
      if (!attMap[row.date]) attMap[row.date] = {};
      if (row.session_type === 'morning') {
        attMap[row.date].morning = row;
      } else {
        attMap[row.date].afternoon = row;
      }
    }

    // Fetch adjustments
    const adjustments = await this.getAdjustments(userId, month, year);
    let totalAdditions = 0;
    let totalPenalties = 0;
    for (const adj of adjustments) {
      if (adj.adjustmentType === 'addition' || adj.adjustmentType === 'bonus') {
        totalAdditions += adj.amount;
      } else if (adj.adjustmentType === 'deduction' || adj.adjustmentType === 'penalty') {
        totalPenalties += adj.amount;
      }
    }

    // Iterate through every single day of the month
    const breakdown: DailyBreakdownItem[] = [];
    let weekendCount = 0;
    let holidayCount = 0;
    let presentDays = 0;
    let halfDays = 0;
    let paidLeaveDays = 0;
    let unpaidLeaveDays = 0;
    let missingLoginDays = 0;
    let confirmedAbsentDays = 0;

    for (let day = 1; day <= daysInMonth; day++) {
      const dateObj = new Date(year, month - 1, day);
      const yyyy = year;
      const mm = String(month).padStart(2, '0');
      const dd = String(day).padStart(2, '0');
      const dateStr = `${yyyy}-${mm}-${dd}`;

      const dayOfWeekIdx = dateObj.getDay(); // 0 = Sun, 5 = Fri, 6 = Sat
      const dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
      const dayName = dayNames[dayOfWeekIdx];

      // Regional corporate calendar: Friday and Saturday are weekends
      const isWeekend = dayOfWeekIdx === 5 || dayOfWeekIdx === 6;
      if (isWeekend) weekendCount++;

      // Check Holiday
      const isHoliday = holidayMap.has(dateStr);
      const holidayName = holidayMap.get(dateStr);
      if (isHoliday && !isWeekend) holidayCount++;

      // Check Leave
      let isLeave = false;
      let leaveType: string | undefined;
      let isPaidLeave = false;
      for (const l of leaves) {
        if (dateStr >= l.startDate && dateStr <= l.endDate && l.isApproved) {
          isLeave = true;
          leaveType = l.leaveType;
          isPaidLeave = l.leaveType !== 'unpaid';
          break;
        }
      }

      const isFuture = dateStr > todayIso;
      const isToday = dateStr === todayIso;

      const dayAtt = attMap[dateStr] || {};
      const morningRecord = dayAtt.morning;
      const afternoonRecord = dayAtt.afternoon;

      const morningAttended = Boolean(morningRecord && morningRecord.status !== 'confirmed_absent');
      const afternoonAttended = Boolean(afternoonRecord && afternoonRecord.status !== 'confirmed_absent');

      let status: DailyBreakdownItem['status'];
      let presentWeight = 0;
      let deductionUnits = 0;
      let notes = '';

      if (isWeekend) {
        status = 'weekend';
        notes = 'Weekend non-working day';
      } else if (isHoliday) {
        status = 'holiday';
        notes = `Official Holiday: ${holidayName}`;
      } else if (isLeave) {
        if (isPaidLeave) {
          status = 'paid_leave';
          presentWeight = 1.0;
          paidLeaveDays += 1;
          notes = `Approved Paid Leave (${leaveType})`;
        } else {
          status = 'unpaid_leave';
          deductionUnits = 1.0;
          unpaidLeaveDays += 1;
          notes = `Approved Unpaid Leave (${leaveType})`;
        }
      } else if (morningAttended && afternoonAttended) {
        status = 'present';
        presentWeight = 1.0;
        presentDays += 1;
        notes = 'Full day attendance recorded';
      } else if (morningAttended || afternoonAttended) {
        status = 'half_day';
        presentWeight = 0.5;
        deductionUnits = isToday ? 0.0 : 0.5;
        if (!isToday) {
          halfDays += 1;
        }
        notes = morningAttended
          ? (isToday ? 'Morning session attended (afternoon in progress)' : 'Morning session only (Half Day)')
          : (isToday ? 'Afternoon session attended' : 'Afternoon session only (Half Day)');
      } else if (isFuture || isToday) {
        status = 'upcoming';
        notes = isToday ? 'Current workday (in progress)' : 'Scheduled working day (Upcoming)';
      } else {
        // Scheduled working day in the past with no punch
        const isExplicitlyConfirmedAbsent =
          (morningRecord && morningRecord.status === 'confirmed_absent') ||
          (afternoonRecord && afternoonRecord.status === 'confirmed_absent');

        // Bug 7 Fix: Do NOT deduct salary for today — the workday is still in progress
        const isToday = dateStr === todayIso;
        if (isToday) {
          status = 'upcoming';
          notes = 'Workday still in progress (no deduction)';
        } else if (isExplicitlyConfirmedAbsent) {
          status = 'confirmed_absent';
          deductionUnits = 1.0;
          confirmedAbsentDays += 1;
          notes = morningRecord?.notes || 'Confirmed Unpaid Absence';
        } else {
          // Missing login record vs confirmed absence
          status = 'missing_record';
          // System policy: Unconfirmed missing days count as unpaid absence pending review
          deductionUnits = 1.0;
          missingLoginDays += 1;
          notes = 'Missing login record (Pending HR review)';
        }
      }

      breakdown.push({
        date: dateStr,
        dayOfWeek: dayName,
        isWeekend,
        isHoliday,
        holidayName,
        isLeave,
        leaveType,
        isPaidLeave,
        isFuture,
        morningAttended,
        morningTime: morningRecord?.login_time,
        morningLocation: morningRecord?.latitude
          ? {
              lat: parseFloat(morningRecord.latitude),
              lng: parseFloat(morningRecord.longitude),
              address: morningRecord.address_text,
            }
          : undefined,
        afternoonAttended,
        afternoonTime: afternoonRecord?.login_time,
        afternoonLocation: afternoonRecord?.latitude
          ? {
              lat: parseFloat(afternoonRecord.latitude),
              lng: parseFloat(afternoonRecord.longitude),
              address: afternoonRecord.address_text,
            }
          : undefined,
        status,
        presentWeight,
        deductionUnits,
        notes,
      });
    }

    const scheduledWorkingDays = daysInMonth - weekendCount - holidayCount;
    const configuredPayableWorkingDays = salaryProfile.standardWorkingDays || scheduledWorkingDays || 22;

    // Daily Salary Rate = Monthly Salary ÷ Configured Payable Working Days
    const dailySalaryRate = Math.round((salaryProfile.monthlySalary / configuredPayableWorkingDays) * 100) / 100;

    // Total deductions = (confirmedAbsentDays + unpaidLeaveDays + missingLoginDays + halfDays * 0.5) * dailySalaryRate
    const totalDeductionUnits = confirmedAbsentDays + unpaidLeaveDays + missingLoginDays + halfDays * 0.5;
    const totalAbsenceDeductions = Math.round(totalDeductionUnits * dailySalaryRate * 100) / 100;

    // Final Payable Salary = Monthly Salary − Total Unpaid Absence Deductions + Additions - Penalties
    const grossPayable = salaryProfile.monthlySalary - totalAbsenceDeductions + totalAdditions - totalPenalties;
    const finalPayableSalary = Math.max(0, Math.round(grossPayable * 100) / 100);

    // Check if saved calculation exists in salary_calculations
    const calcRes = await this.db.query(
      'SELECT id, status FROM salary_calculations WHERE user_id = $1 AND month = $2 AND year = $3',
      [userId, month, year],
    );
    const isConfirmed = Boolean(calcRes?.rows?.length && calcRes.rows[0]?.status === 'confirmed');

    return {
      userId,
      userName: salaryProfile.userName,
      userEmail: salaryProfile.userEmail,
      department: salaryProfile.department,
      designation: salaryProfile.designation,
      month,
      year,
      monthlyBaseSalary: salaryProfile.monthlySalary,
      currency: salaryProfile.currency,
      calendarDaysInMonth: daysInMonth,
      weekendDays: weekendCount,
      holidayDays: holidayCount,
      scheduledWorkingDays,
      configuredPayableWorkingDays,
      dailySalaryRate,
      presentDays,
      halfDays,
      paidLeaveDays,
      unpaidLeaveDays,
      missingLoginDays,
      confirmedAbsentDays,
      totalAbsenceDeductions,
      totalAdditions,
      totalPenalties,
      finalPayableSalary,
      isConfirmed,
      dailyBreakdown: breakdown,
    };
  }

  /**
   * Save calculation into salary_calculations table for auditing and payroll finalization
   */
  async saveSalaryCalculation(userId: string, month: number, year: number, calculatedBy?: string, notes?: string) {
    const calc = await this.calculateSalary(userId, month, year);

    await this.db.query(
      `INSERT INTO salary_calculations (
          user_id, month, year, base_salary, working_days, present_days, absent_days,
          missing_days, holidays_count, weekend_days, paid_leave_days, unpaid_leave_days,
          daily_rate, total_deductions, bonus_or_additions, final_payable, status, notes,
          calculated_by, calculated_at, updated_at
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, 'confirmed', $17, $18, clock_timestamp(), clock_timestamp())
       ON CONFLICT (user_id, month, year)
       DO UPDATE SET
          base_salary = EXCLUDED.base_salary,
          working_days = EXCLUDED.working_days,
          present_days = EXCLUDED.present_days,
          absent_days = EXCLUDED.absent_days,
          missing_days = EXCLUDED.missing_days,
          holidays_count = EXCLUDED.holidays_count,
          weekend_days = EXCLUDED.weekend_days,
          paid_leave_days = EXCLUDED.paid_leave_days,
          unpaid_leave_days = EXCLUDED.unpaid_leave_days,
          daily_rate = EXCLUDED.daily_rate,
          total_deductions = EXCLUDED.total_deductions,
          bonus_or_additions = EXCLUDED.bonus_or_additions,
          final_payable = EXCLUDED.final_payable,
          status = 'confirmed',
          notes = EXCLUDED.notes,
          calculated_by = EXCLUDED.calculated_by,
          updated_at = clock_timestamp()`,
      [
        userId,
        month,
        year,
        calc.monthlyBaseSalary,
        calc.configuredPayableWorkingDays,
        calc.presentDays + calc.halfDays * 0.5,
        calc.confirmedAbsentDays + calc.unpaidLeaveDays,
        calc.missingLoginDays,
        calc.holidayDays,
        calc.weekendDays,
        calc.paidLeaveDays,
        calc.unpaidLeaveDays,
        calc.dailySalaryRate,
        calc.totalAbsenceDeductions,
        calc.totalAdditions - calc.totalPenalties,
        calc.finalPayableSalary,
        notes || 'Confirmed and audited by admin',
        calculatedBy || null,
      ],
    );

    return { success: true, message: `Salary calculation for ${calc.userName} (${month}/${year}) confirmed successfully`, calculation: calc };
  }

  /**
   * Organizational Monthly Salary Report
   * Summarizes all employees for a given month and year
   */
  async getOrgSalaryReport(month: number, year: number) {
    const usersRes = await this.db.query(
      `SELECT id, full_name, email, department, designation, role, avatar_url
       FROM users
       WHERE is_active = TRUE
       ORDER BY department ASC, full_name ASC`,
    );

    const calculations: SalaryCalculationResult[] = [];
    let totalBaseSalary = 0;
    let totalDeductions = 0;
    let totalPayable = 0;

    for (const u of usersRes.rows) {
      const calc = await this.calculateSalary(u.id, month, year);
      calculations.push(calc);
      totalBaseSalary += calc.monthlyBaseSalary;
      totalDeductions += calc.totalAbsenceDeductions;
      totalPayable += calc.finalPayableSalary;
    }

    return {
      month,
      year,
      totalEmployees: usersRes.rows.length,
      currency: 'BDT',
      totalBaseSalary: Math.round(totalBaseSalary * 100) / 100,
      totalDeductions: Math.round(totalDeductions * 100) / 100,
      totalPayable: Math.round(totalPayable * 100) / 100,
      employees: calculations,
    };
  }
}
