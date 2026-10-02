import { Controller, Post, Get, Body, Query, UseGuards, Request, HttpCode, HttpStatus, Param } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AttendanceService } from './attendance.service';
import { CheckInDto } from './dto/check-in.dto';

@Controller('attendance')
export class AttendanceController {
  constructor(private readonly attendanceService: AttendanceService) {}

  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  @Post('check-in')
  async checkIn(@Body() dto: CheckInDto, @Request() req: any) {
    return this.attendanceService.checkIn(req.user.id, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Get()
  async getAttendanceRecords(
    @Query('userId') userId: string,
    @Query('date') date: string,
    @Query('month') month: string,
    @Query('year') year: string,
    @Query('sessionType') sessionType: string,
    @Request() req: any,
  ) {
    return this.attendanceService.getAttendanceRecords({
      userId: userId || undefined,
      date: date || undefined,
      month: month ? parseInt(month, 10) : undefined,
      year: year ? parseInt(year, 10) : undefined,
      sessionType: sessionType || undefined,
      currentUserRole: req.user.role || 'project_member',
      currentUserId: req.user.id,
    });
  }

  @UseGuards(JwtAuthGuard)
  @Get('summary')
  async getSummary(
    @Query('userId') userId: string,
    @Query('month') month: string,
    @Query('year') year: string,
    @Request() req: any,
  ) {
    const targetUserId = userId || req.user.id;
    const targetMonth = month ? parseInt(month, 10) : new Date().getMonth() + 1;
    const targetYear = year ? parseInt(year, 10) : new Date().getFullYear();

    return this.attendanceService.getAttendanceSummary(targetUserId, targetMonth, targetYear);
  }

  @UseGuards(JwtAuthGuard)
  @Get('daily-overview')
  async getDailyOverview(@Query('date') date: string) {
    return this.attendanceService.getDailyOverview(date);
  }

  @UseGuards(JwtAuthGuard)
  @Post('confirm-absence')
  async confirmAbsence(
    @Body() body: { userId: string; date: string; notes?: string },
    @Request() req: any,
  ) {
    return this.attendanceService.confirmAbsence(body.userId, body.date, body.notes, req.user.id);
  }
}
