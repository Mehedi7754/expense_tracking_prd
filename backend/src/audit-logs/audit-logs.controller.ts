import { Controller, Get, Post, Body, Query, UseGuards, Request } from '@nestjs/common';
import { AuditLogsService } from './audit-logs.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('audit-logs')
export class AuditLogsController {
  constructor(private readonly auditLogsService: AuditLogsService) {}

  @Roles('main_admin')
  @Get()
  async getAuditLogs(@Query('limit') limit?: string) {
    return this.auditLogsService.findAll(limit ? parseInt(limit, 10) : 100);
  }

  @Post()
  async createAuditLog(@Body() body: any, @Request() req: any) {
    return this.auditLogsService.log(body, req.user?.id);
  }
}
