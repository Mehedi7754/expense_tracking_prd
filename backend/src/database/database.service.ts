import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Pool, PoolClient, QueryResult, QueryResultRow } from 'pg';

@Injectable()
export class DatabaseService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(DatabaseService.name);
  private pool: Pool;

  constructor(private readonly config: ConfigService) {
    this.pool = new Pool({
      host: this.config.get<string>('DB_HOST', 'localhost'),
      port: Number(this.config.get<number>('DB_PORT', 5433)),
      database: this.config.get<string>('DB_NAME', 'spendwise_db'),
      user: this.config.get<string>('DB_USER', 'spendwise'),
      password: this.config.get<string>('DB_PASSWORD', 'spendwise123'),
      max: Number(this.config.get<number>('DB_POOL_MAX', 10)),
      idleTimeoutMillis: Number(this.config.get<number>('DB_IDLE_TIMEOUT', 30000)),
      connectionTimeoutMillis: Number(this.config.get<number>('DB_CONN_TIMEOUT', 2000)),
    });

    this.pool.on('error', (err) => {
      this.logger.error('Unexpected error on idle PostgreSQL client', err.stack);
    });
  }

  async onModuleInit() {
    try {
      const res = await this.pool.query('SELECT NOW() AS current_time');
      this.logger.log(`Database connected successfully: ${res.rows[0].current_time}`);
      // Auto-migrate missing columns for image uploads
      await this.pool.query('ALTER TABLE projects ADD COLUMN IF NOT EXISTS image_url TEXT;');
      await this.pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url TEXT;');

      // Auto-migrate Attendance & Geo-Location Tracking Tables
      await this.pool.query(`
        CREATE TABLE IF NOT EXISTS attendance_records (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            date DATE NOT NULL DEFAULT CURRENT_DATE,
            session_type VARCHAR(20) NOT NULL DEFAULT 'morning',
            login_time TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
            latitude NUMERIC(10, 7),
            longitude NUMERIC(10, 7),
            address_text TEXT DEFAULT '',
            device_info TEXT DEFAULT '',
            status VARCHAR(20) NOT NULL DEFAULT 'present',
            notes TEXT DEFAULT '',
            created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
            updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
            CONSTRAINT uq_user_date_session UNIQUE (user_id, date, session_type)
        );
        CREATE INDEX IF NOT EXISTS idx_attendance_user_date ON attendance_records(user_id, date DESC);
        CREATE INDEX IF NOT EXISTS idx_attendance_date ON attendance_records(date DESC);

        CREATE TABLE IF NOT EXISTS employee_salaries (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE UNIQUE,
            monthly_salary NUMERIC(15, 2) NOT NULL DEFAULT 50000.00,
            currency VARCHAR(3) NOT NULL DEFAULT 'BDT',
            standard_working_days INT NOT NULL DEFAULT 22,
            effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
            effective_to DATE,
            created_by UUID REFERENCES users(id) ON DELETE SET NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
            updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
        );
        CREATE INDEX IF NOT EXISTS idx_employee_salaries_user_id ON employee_salaries(user_id);

        CREATE TABLE IF NOT EXISTS holidays (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            date DATE NOT NULL UNIQUE,
            name VARCHAR(150) NOT NULL,
            is_recurring BOOLEAN NOT NULL DEFAULT FALSE,
            created_by UUID REFERENCES users(id) ON DELETE SET NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
        );
        CREATE INDEX IF NOT EXISTS idx_holidays_date ON holidays(date);

        CREATE TABLE IF NOT EXISTS leave_records (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            start_date DATE NOT NULL,
            end_date DATE NOT NULL,
            leave_type VARCHAR(50) NOT NULL DEFAULT 'paid',
            reason TEXT NOT NULL DEFAULT '',
            is_approved BOOLEAN NOT NULL DEFAULT TRUE,
            approved_by UUID REFERENCES users(id) ON DELETE SET NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
            updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
        );
        CREATE INDEX IF NOT EXISTS idx_leave_records_user_dates ON leave_records(user_id, start_date, end_date);

        CREATE TABLE IF NOT EXISTS salary_calculations (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            month INT NOT NULL,
            year INT NOT NULL,
            base_salary NUMERIC(15, 2) NOT NULL,
            working_days INT NOT NULL,
            present_days NUMERIC(5, 1) NOT NULL DEFAULT 0.0,
            absent_days NUMERIC(5, 1) NOT NULL DEFAULT 0.0,
            missing_days NUMERIC(5, 1) NOT NULL DEFAULT 0.0,
            holidays_count INT NOT NULL DEFAULT 0,
            weekend_days INT NOT NULL DEFAULT 0,
            paid_leave_days NUMERIC(5, 1) NOT NULL DEFAULT 0.0,
            unpaid_leave_days NUMERIC(5, 1) NOT NULL DEFAULT 0.0,
            daily_rate NUMERIC(15, 2) NOT NULL,
            total_deductions NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
            bonus_or_additions NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
            final_payable NUMERIC(15, 2) NOT NULL,
            status VARCHAR(20) NOT NULL DEFAULT 'calculated',
            notes TEXT DEFAULT '',
            calculated_by UUID REFERENCES users(id) ON DELETE SET NULL,
            calculated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
            updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
            CONSTRAINT uq_user_month_year UNIQUE (user_id, month, year)
        );
        CREATE INDEX IF NOT EXISTS idx_salary_calc_user_period ON salary_calculations(user_id, year, month);
        CREATE INDEX IF NOT EXISTS idx_salary_calc_period ON salary_calculations(year, month);

        CREATE TABLE IF NOT EXISTS salary_adjustments (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            salary_calculation_id UUID REFERENCES salary_calculations(id) ON DELETE CASCADE,
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            adjustment_type VARCHAR(20) NOT NULL,
            amount NUMERIC(15, 2) NOT NULL,
            reason TEXT NOT NULL,
            adjusted_by UUID REFERENCES users(id) ON DELETE SET NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
        );
        CREATE INDEX IF NOT EXISTS idx_salary_adj_calc_id ON salary_adjustments(salary_calculation_id);
      `);

      // Ensure default super admin exists ($2a$10$NcceR3EX5RYDA/ogM9Sys.TztdGvbBlJ4K630rzHG4E9Iole0NK6S = "password123")
      try {
        await this.pool.query(`
          INSERT INTO users (id, email, password_hash, full_name, role, department, designation, phone, is_active)
          VALUES
            ('a0000000-0000-0000-0000-000000000001', 'admin@pfis.com', '$2a$10$NcceR3EX5RYDA/ogM9Sys.TztdGvbBlJ4K630rzHG4E9Iole0NK6S', 'Eleanor Vance', 'main_admin', 'Corporate Governance', 'Managing Director / Admin', '+880 1711-000001', TRUE),
            ('a0000000-0000-0000-0000-000000000002', 'admin@example.com', '$2a$10$NcceR3EX5RYDA/ogM9Sys.TztdGvbBlJ4K630rzHG4E9Iole0NK6S', 'Super Admin', 'main_admin', 'Management', 'System Administrator', '+880 1711-000002', TRUE),
            ('a0000000-0000-0000-0000-000000000003', 'manager@example.com', '$2a$10$NcceR3EX5RYDA/ogM9Sys.TztdGvbBlJ4K630rzHG4E9Iole0NK6S', 'Project Manager', 'project_manager', 'Engineering', 'Lead PM', '+880 1711-000003', TRUE),
            ('a0000000-0000-0000-0000-000000000004', 'employee@example.com', '$2a$10$NcceR3EX5RYDA/ogM9Sys.TztdGvbBlJ4K630rzHG4E9Iole0NK6S', 'John Employee', 'project_member', 'Development', 'Software Engineer', '+880 1711-000004', TRUE),
            ('a0000000-0000-0000-0000-000000000005', 'finance@example.com', '$2a$10$NcceR3EX5RYDA/ogM9Sys.TztdGvbBlJ4K630rzHG4E9Iole0NK6S', 'Finance Officer', 'finance', 'Accounts', 'Finance Lead', '+880 1711-000005', TRUE)
          ON CONFLICT (email) DO UPDATE SET password_hash = EXCLUDED.password_hash, is_active = TRUE;
        `);
        this.logger.log('Verified core seed users in PostgreSQL.');
      } catch (seedErr: any) {
        this.logger.warn(`Non-blocking seed users note: ${seedErr.message}`);
      }
    } catch (err: any) {
      this.logger.error(`Database connection failed: ${err.message}`, err.stack);
      throw err;
    }
  }

  async ping(): Promise<boolean> {
    try {
      await this.pool.query('SELECT 1');
      return true;
    } catch (_) {
      return false;
    }
  }

  async onModuleDestroy() {
    await this.pool.end();
    this.logger.log('Database connection pool closed');
  }

  async query<T extends QueryResultRow = any>(text: string, params: any[] = []): Promise<QueryResult<T>> {
    const start = Date.now();
    try {
      const res = await this.pool.query<T>(text, params);
      const duration = Date.now() - start;
      if (duration > 150) {
        this.logger.warn(`Slow query (${duration}ms): ${text}`);
      }
      return res;
    } catch (err: any) {
      this.logger.error(`Query error in: ${text} -> ${err.message}`);
      throw err;
    }
  }

  async transaction<T>(callback: (client: PoolClient) => Promise<T>): Promise<T> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const result = await callback(client);
      await client.query('COMMIT');
      return result;
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }
}
