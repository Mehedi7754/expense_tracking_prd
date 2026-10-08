import { Controller, Get, Post, Patch, Delete, Param, Body, UseGuards, Request } from '@nestjs/common';
import { NotificationsService } from './notifications.service';
import { FcmService } from './fcm.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@UseGuards(JwtAuthGuard)
@Controller('notifications')
export class NotificationsController {
  constructor(
    private readonly notificationsService: NotificationsService,
    private readonly fcmService: FcmService,
  ) {}

  @Get()
  async getNotifications(@Request() req: any) {
    return this.notificationsService.findAll(req.user.id);
  }

  @Patch(':id/read')
  async markAsRead(@Param('id') id: string, @Request() req: any) {
    return this.notificationsService.markAsRead(id, req.user.id);
  }

  @Delete('all')
  async deleteAll(@Request() req: any) {
    return this.notificationsService.deleteAll(req.user.id);
  }

  @Delete(':id')
  async deleteOne(@Param('id') id: string, @Request() req: any) {
    return this.notificationsService.delete(id, req.user.id);
  }

  @Post('fcm-token')
  async registerFcmToken(
    @Request() req: any,
    @Body() body: { token: string; deviceInfo?: string },
  ) {
    return this.fcmService.saveToken(req.user.id, body.token, body.deviceInfo);
  }
}

