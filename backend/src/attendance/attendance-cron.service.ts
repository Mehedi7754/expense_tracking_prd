import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { DatabaseService } from '../database/database.service';
import { AttendanceService } from './attendance.service';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class AttendanceCronService {
  private readonly logger = new Logger(AttendanceCronService.name);

  constructor(
    private readonly db: DatabaseService,
    private readonly attendanceService: AttendanceService,
    private readonly notificationsService: NotificationsService,
  ) {}

  // Run every 30 minutes
  @Cron('*/30 * * * *')
  async handleCheckInReminders() {
    this.logger.debug('Running scheduled check-in reminders check...');

    try {
      // 1. Get active employees (exclude main_admin and finance who don't need to check in)
      const usersRes = await this.db.query(
        `SELECT id, full_name, email FROM users WHERE is_active = TRUE AND role NOT IN ('main_admin', 'finance')`,
      );
      const employees = usersRes.rows;

      if (employees.length === 0) return;

      const timingSettings = await this.attendanceService.getTimingSettings();
      const userShifts = timingSettings.userShifts || {};
      const shifts = timingSettings.shifts || [];

      // Default shift fallback
      const defaultShift = shifts.find((s) => s.isDefault) || {
        id: 'shift_default',
        name: 'General Office Shift',
        morningStartHour: 9,
        morningEndHour: 13,
        afternoonStartHour: 13,
        afternoonEndHour: 18,
        weekendDays: [5, 6],
      };

      // Local time in Dhaka
      const dhakaNow = new Date(new Date().toLocaleString('en-US', { timeZone: 'Asia/Dhaka' }));
      const currentHour = dhakaNow.getHours();
      const currentMinute = dhakaNow.getMinutes();
      const currentDayOfWeek = dhakaNow.getDay() === 0 ? 7 : dhakaNow.getDay();

      for (const emp of employees) {
        const shiftId = userShifts[emp.id];
        const shift = shifts.find((s) => s.id === shiftId) || defaultShift;

        // Skip if it's their weekend
        if (shift.weekendDays?.includes(currentDayOfWeek)) {
          continue;
        }

        // Check if shift is starting in the next 30 minutes
        // We evaluate morning and afternoon separately.
        
        let targetSession: 'morning' | 'afternoon' | null = null;
        let isApproaching = false;

        // Morning check: if current hour is 1 hour before start, OR it's the exact hour and minutes < 30
        if (
          (currentHour === shift.morningStartHour - 1 && currentMinute >= 30) ||
          (currentHour === shift.morningStartHour && currentMinute < 15)
        ) {
          targetSession = 'morning';
          isApproaching = true;
        }

        // Afternoon check
        const afternoonStartHour = shift.afternoonStartHour ?? shift.morningEndHour ?? 13;
        if (
          (currentHour === afternoonStartHour - 1 && currentMinute >= 30) ||
          (currentHour === afternoonStartHour && currentMinute < 15)
        ) {
          targetSession = 'afternoon';
          isApproaching = true;
        }

        if (isApproaching && targetSession) {
          // Verify they haven't checked in yet for this session today
          const checkInRes = await this.db.query(
            `SELECT id FROM attendance_records WHERE user_id = $1 AND date = CURRENT_DATE AND session_type = $2`,
            [emp.id, targetSession],
          );

          if (checkInRes.rows.length === 0) {
            // Send Push Notification Reminder
            await this.notificationsService.create({
              userId: emp.id,
              title: 'Check-in Reminder ⏰',
              message: `Your ${targetSession} session starts soon. Don't forget to check in!`,
              type: 'attendance_reminder',
            });
            this.logger.log(`Sent check-in reminder to ${emp.full_name} for ${targetSession} session.`);
          }
        }
      }
    } catch (error) {
      this.logger.error('Error during handleCheckInReminders cron job', error);
    }
  }
}
