import {
  Controller,
  Delete,
  Get,
  Post,
  Param,
  Body,
  UseGuards,
  Request,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { DatabaseService } from '../database/database.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('main_admin')
@Controller('admin')
export class AdminController {
  constructor(private readonly db: DatabaseService) {}

  /** List all wipe backups */
  @Get('data-backups')
  async listBackups() {
    const res = await this.db.query(
      `SELECT id, created_at, wiped_by, row_counts FROM data_wipe_backups ORDER BY created_at DESC LIMIT 20`,
      [],
    );
    return res.rows.map((r) => ({
      id: r.id,
      createdAt: r.created_at,
      wipedBy: r.wiped_by,
      rowCounts: r.row_counts,
    }));
  }

  /** Wipe all non-admin data with a confirmToken. Creates a backup record first. */
  @Delete('wipe-all-data')
  async wipeAllData(
    @Body('confirmToken') confirmToken: string,
    @Request() req: any,
  ) {
    if (!confirmToken || confirmToken.length !== 12) {
      throw new BadRequestException('Invalid confirmation token');
    }

    // Count rows before wipe for backup record
    const counts: Record<string, number> = {};
    const tables = [
      'projects', 'project_members', 'expenses', 'expense_comments',
      'attendance_records', 'tasks', 'notifications', 'chat_messages',
      'fcm_tokens', 'salary_calculations', 'leaves', 'holidays', 'categories',
    ];
    for (const table of tables) {
      try {
        const r = await this.db.query(`SELECT COUNT(*) FROM ${table}`, []);
        counts[table] = parseInt(r.rows[0]?.count || '0', 10);
      } catch {
        counts[table] = 0;
      }
    }

    // Ensure backup table exists
    await this.db.query(
      `CREATE TABLE IF NOT EXISTS data_wipe_backups (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        created_at TIMESTAMPTZ DEFAULT NOW(),
        wiped_by UUID,
        row_counts JSONB
      )`,
      [],
    );

    // Insert backup record
    const backupRes = await this.db.query(
      `INSERT INTO data_wipe_backups (wiped_by, row_counts) VALUES ($1, $2) RETURNING id`,
      [req.user.id, JSON.stringify(counts)],
    );
    const backupId = backupRes.rows[0]?.id;

    // Wipe all data (preserve admin/main_admin users)
    const wipeOrder = [
      'expense_comments',
      'expenses',
      'chat_messages',
      'fcm_tokens',
      'attendance_records',
      'tasks',
      'notifications',
      'project_members',
      'projects',
      'salary_calculations',
      'leaves',
      'holidays',
      'categories',
    ];

    for (const table of wipeOrder) {
      try {
        await this.db.query(`DELETE FROM ${table}`, []);
      } catch (err) {
        // Skip tables that don't exist
        console.warn(`Wipe skipped table ${table}:`, err?.message);
      }
    }

    // Delete non-admin users
    await this.db.query(
      `DELETE FROM users WHERE role::text NOT IN ('main_admin', 'admin') AND is_active = TRUE`,
      [],
    );

    return { success: true, backupId };
  }

  /** Revert from a backup (restores row count info only — full restore not supported, marks backup as reverted) */
  @Post('data-backups/:id/revert')
  async revertBackup(@Param('id') id: string) {
    const res = await this.db.query(
      `SELECT id, row_counts FROM data_wipe_backups WHERE id = $1`,
      [id],
    );
    if (!res.rows[0]) {
      throw new BadRequestException('Backup not found');
    }
    // Mark as reverted
    await this.db.query(
      `UPDATE data_wipe_backups SET row_counts = row_counts || '{"reverted": true}'::jsonb WHERE id = $1`,
      [id],
    );
    return {
      success: true,
      message: 'Backup marked as reverted. Data cannot be automatically restored as it was permanently deleted. Please restore from your database backup.',
      rowCounts: res.rows[0].row_counts,
    };
  }
}
