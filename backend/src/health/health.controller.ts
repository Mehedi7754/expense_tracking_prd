import { Controller, Get } from '@nestjs/common';
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
}
