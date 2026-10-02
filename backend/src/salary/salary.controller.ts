import {
  Controller,
  Get,
  Post,
  Delete,
  Body,
  Param,
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
import { SalaryService } from './salary.service';
import { SetSalaryDto } from './dto/set-salary.dto';
import { CreateHolidayDto } from './dto/holiday.dto';
import { CreateLeaveDto } from './dto/leave.dto';
import { CreateAdjustmentDto } from './dto/adjustment.dto';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('salary')
export class SalaryController {
  constructor(private readonly salaryService: SalaryService) {}

  private checkCanViewUserData(currentUser: any, targetUserId: string, message: string) {
    const isAdminOrFinance =
      currentUser?.role === 'main_admin' ||
      currentUser?.role === 'finance_manager' ||
      currentUser?.role === 'finance';
    if (!isAdminOrFinance && currentUser?.id !== targetUserId) {
      throw new ForbiddenException(message);
    }
  }

  @Get('employee/:userId')
  async getEmployeeSalary(@Param('userId') userId: string, @Request() req: any) {
    this.checkCanViewUserData(req.user, userId, 'You can only view your own salary profile');
    return this.salaryService.getEmployeeSalary(userId);
  }

  @Roles('main_admin', 'finance_manager')
  @Post('employee/:userId')
  async setEmployeeSalary(
    @Param('userId') userId: string,
    @Body() dto: SetSalaryDto,
    @Request() req: any,
  ) {
    return this.salaryService.setEmployeeSalary(userId, dto, req.user.id);
  }

  @Get('calculate/:userId')
  async calculateSalary(
    @Param('userId') userId: string,
    @Query('month') month: string,
    @Query('year') year: string,
    @Request() req: any,
  ) {
    this.checkCanViewUserData(req.user, userId, 'You can only view your own salary calculation');
    const targetMonth = month ? parseInt(month, 10) : new Date().getMonth() + 1;
    const targetYear = year ? parseInt(year, 10) : new Date().getFullYear();
    return this.salaryService.calculateSalary(userId, targetMonth, targetYear);
  }

  @Roles('main_admin', 'finance_manager')
  @HttpCode(HttpStatus.OK)
  @Post('save-calculation')
  async saveCalculation(
    @Body() body: { userId: string; month: number; year: number; notes?: string },
    @Request() req: any,
  ) {
    return this.salaryService.saveSalaryCalculation(body.userId, body.month, body.year, req.user.id, body.notes);
  }

  @Roles('main_admin', 'finance_manager')
  @Get('report')
  async getOrgSalaryReport(
    @Query('month') month: string,
    @Query('year') year: string,
  ) {
    const targetMonth = month ? parseInt(month, 10) : new Date().getMonth() + 1;
    const targetYear = year ? parseInt(year, 10) : new Date().getFullYear();
    return this.salaryService.getOrgSalaryReport(targetMonth, targetYear);
  }

  // --- Holidays ---
  @Get('holidays')
  async getHolidays(@Query('year') year: string) {
    const targetYear = year ? parseInt(year, 10) : undefined;
    return this.salaryService.getHolidays(targetYear);
  }

  @Roles('main_admin', 'finance_manager')
  @Post('holidays')
  async addHoliday(@Body() dto: CreateHolidayDto, @Request() req: any) {
    return this.salaryService.addHoliday(dto, req.user.id);
  }

  @Roles('main_admin', 'finance_manager')
  @Delete('holidays/:id')
  async deleteHoliday(@Param('id') id: string) {
    return this.salaryService.deleteHoliday(id);
  }

  // --- Leaves ---
  @Get('leaves')
  async getLeaves(
    @Query('userId') userId: string,
    @Query('month') month: string,
    @Query('year') year: string,
    @Request() req: any,
  ) {
    const targetMonth = month ? parseInt(month, 10) : undefined;
    const targetYear = year ? parseInt(year, 10) : undefined;
    if (userId) {
      this.checkCanViewUserData(req.user, userId, 'You can only view your own leave records');
    }
    const queryUserId = userId || (req.user.role === 'project_member' ? req.user.id : undefined);
    return this.salaryService.getLeaves(queryUserId, targetMonth, targetYear);
  }

  @Post('leaves')
  async addLeave(@Body() dto: CreateLeaveDto, @Request() req: any) {
    // If not admin/finance, employee can only request leave for themselves
    const isAdminOrFinance =
      req.user.role === 'main_admin' ||
      req.user.role === 'finance_manager' ||
      req.user.role === 'finance';
    if (!isAdminOrFinance && dto.userId && dto.userId !== req.user.id) {
      throw new ForbiddenException('You can only submit leaves for yourself');
    }
    return this.salaryService.addLeave(dto, req.user.id);
  }

  @Roles('main_admin', 'finance_manager')
  @Delete('leaves/:id')
  async deleteLeave(@Param('id') id: string) {
    return this.salaryService.deleteLeave(id);
  }

  // --- Adjustments ---
  @Get('adjustments/:userId')
  async getAdjustments(
    @Param('userId') userId: string,
    @Query('month') month: string,
    @Query('year') year: string,
    @Request() req: any,
  ) {
    this.checkCanViewUserData(req.user, userId, 'You can only view your own adjustments');
    const targetMonth = month ? parseInt(month, 10) : undefined;
    const targetYear = year ? parseInt(year, 10) : undefined;
    return this.salaryService.getAdjustments(userId, targetMonth, targetYear);
  }

  @Roles('main_admin', 'finance_manager')
  @Post('adjustments')
  async addAdjustment(@Body() dto: CreateAdjustmentDto, @Request() req: any) {
    return this.salaryService.addAdjustment(dto, req.user.id);
  }
}
