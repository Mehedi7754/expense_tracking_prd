import { Controller, Get, Post, Body, Query, UseGuards, Request } from '@nestjs/common';
import { AuditLogsService } from './audit-logs.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@UseGuards(JwtAuthGuard)
@Controller('audit-logs')
export class AuditLogsController {
  constructor(private readonly auditLogsService: AuditLogsService) {}

  @Get()
  async getAuditLogs(@Query('limit') limit?: string) {
    return this.auditLogsService.findAll(limit ? parseInt(limit, 10) : 100);
  }

  @Post()
  async createAuditLog(@Body() body: any, @Request() req: any) {
    return this.auditLogsService.log(body, req.user?.id);
  }
}
