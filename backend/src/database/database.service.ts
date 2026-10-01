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
