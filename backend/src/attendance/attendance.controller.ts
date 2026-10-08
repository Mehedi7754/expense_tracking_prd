import {
  Controller,
  Post,
  Get,
  Body,
  Query,
  UseGuards,
  Request,
  HttpCode,
  HttpStatus,
  ForbiddenException,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { AttendanceService } from './attendance.service';
import { CheckInDto } from './dto/check-in.dto';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('attendance')
export class AttendanceController {
  constructor(private readonly attendanceService: AttendanceService) {}

  @HttpCode(HttpStatus.OK)
  @Post('check-in')
  async checkIn(@Body() dto: CheckInDto, @Request() req: any) {
    return this.attendanceService.checkIn(req.user.id, dto);
  }

  @Get()
  async getAttendanceRecords(
    @Query('userId') userId: string,
    @Query('month') month: string,
    @Query('year') year: string,
    @Request() req: any,
  ) {
    if (userId) {
      if (month && year) {
        return this.attendanceService.getMonthlyRecords(userId, parseInt(year, 10), parseInt(month, 10));
      } else {
        return this.attendanceService.getTodayRecords(); // Simplification
      }
    } else {
      if (month && year) {
        return this.attendanceService.getAllMonthlyRecords(parseInt(year, 10), parseInt(month, 10));
      } else {
        return this.attendanceService.getTodayRecords();
      }
    }
  }

  @Get('summary')
  async getSummary(
    @Query('userId') userId: string,
    @Request() req: any,
  ) {
    const isManagerOrAdmin =
      req.user.role === 'main_admin' ||
      req.user.role === 'project_manager' ||
      req.user.role === 'finance_manager' ||
      req.user.role === 'finance';

    if (!isManagerOrAdmin && userId && userId !== req.user.id) {
      throw new ForbiddenException('You can only view your own attendance summary');
    }

    const targetUserId = isManagerOrAdmin && userId ? userId : req.user.id;
    return this.attendanceService.getSummary(targetUserId);
  }

  @Get('settings')
  async getTimingSettings() {
    return this.attendanceService.getTimingSettings();
  }

  @Roles('main_admin')
  @Post('settings')
  async updateTimingSettings(
    @Body() body: { morningStartHour?: number; morningEndHour: number; afternoonStartHour?: number; afternoonEndHour?: number },
  ) {
    return this.attendanceService.updateTimingSettings(body);
  }
}
