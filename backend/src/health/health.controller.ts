import { Controller, Get, Post, Body, UnauthorizedException } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';

@Controller('health')
export class HealthController {
  constructor(private readonly db: DatabaseService) {}

  @Get()
  async check() {
    const isDbConnected = await this.db.ping();
    return {
      status: isDbConnected ? 'ok' : 'degraded',
      timestamp: new Date().toISOString(),
      database: isDbConnected ? 'connected' : 'disconnected',
      engine: 'NestJS + Fastify (Low-Resource)',
      memoryUsage: process.memoryUsage(),
      uptime: process.uptime(),
    };
  }

  @Post('reset-db')
  async resetDatabase(@Body('secret') secret: string) {
    if (secret !== 'gw_hard_reset_secret_2026') {
      throw new UnauthorizedException('Invalid reset secret');
    }
    await this.db.query(`
      TRUNCATE TABLE 
        salary_adjustments,
        salary_calculations,
        leave_records,
        employee_salaries,
        attendance_records,
        expense_attachments,
        expenses,
        project_categories,
        project_revenues,
        project_members,
        projects,
        clients,
        app_settings,
        app_uploaded_files,
        fcm_device_tokens,
        notifications,
        users
      CASCADE;
    `);
    return { success: true, message: 'All database tables truncated and completely clean.' };
  }
}
