import { Controller, Get, Post, Delete, Body, Param, Query, UseGuards, Request, HttpCode, HttpStatus } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { SalaryService } from './salary.service';
import { SetSalaryDto } from './dto/set-salary.dto';
import { CreateHolidayDto } from './dto/holiday.dto';
import { CreateLeaveDto } from './dto/leave.dto';
import { CreateAdjustmentDto } from './dto/adjustment.dto';

@Controller('salary')
export class SalaryController {
  constructor(private readonly salaryService: SalaryService) {}

  @UseGuards(JwtAuthGuard)
  @Get('employee/:userId')
  async getEmployeeSalary(@Param('userId') userId: string) {
    return this.salaryService.getEmployeeSalary(userId);
  }

  @UseGuards(JwtAuthGuard)
  @Post('employee/:userId')
  async setEmployeeSalary(
    @Param('userId') userId: string,
    @Body() dto: SetSalaryDto,
    @Request() req: any,
  ) {
    return this.salaryService.setEmployeeSalary(userId, dto, req.user.id);
  }

  @UseGuards(JwtAuthGuard)
  @Get('calculate/:userId')
  async calculateSalary(
    @Param('userId') userId: string,
    @Query('month') month: string,
    @Query('year') year: string,
  ) {
    const targetMonth = month ? parseInt(month, 10) : new Date().getMonth() + 1;
    const targetYear = year ? parseInt(year, 10) : new Date().getFullYear();
    return this.salaryService.calculateSalary(userId, targetMonth, targetYear);
  }

  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  @Post('save-calculation')
  async saveCalculation(
    @Body() body: { userId: string; month: number; year: number; notes?: string },
    @Request() req: any,
  ) {
    return this.salaryService.saveSalaryCalculation(body.userId, body.month, body.year, req.user.id, body.notes);
  }

  @UseGuards(JwtAuthGuard)
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
  @UseGuards(JwtAuthGuard)
  @Get('holidays')
  async getHolidays(@Query('year') year: string) {
    const targetYear = year ? parseInt(year, 10) : undefined;
    return this.salaryService.getHolidays(targetYear);
  }

  @UseGuards(JwtAuthGuard)
  @Post('holidays')
  async addHoliday(@Body() dto: CreateHolidayDto, @Request() req: any) {
    return this.salaryService.addHoliday(dto, req.user.id);
  }

  @UseGuards(JwtAuthGuard)
  @Delete('holidays/:id')
  async deleteHoliday(@Param('id') id: string) {
    return this.salaryService.deleteHoliday(id);
  }

  // --- Leaves ---
  @UseGuards(JwtAuthGuard)
  @Get('leaves')
  async getLeaves(
    @Query('userId') userId: string,
    @Query('month') month: string,
    @Query('year') year: string,
  ) {
    const targetMonth = month ? parseInt(month, 10) : undefined;
    const targetYear = year ? parseInt(year, 10) : undefined;
    return this.salaryService.getLeaves(userId || undefined, targetMonth, targetYear);
  }

  @UseGuards(JwtAuthGuard)
  @Post('leaves')
  async addLeave(@Body() dto: CreateLeaveDto, @Request() req: any) {
    return this.salaryService.addLeave(dto, req.user.id);
  }

  @UseGuards(JwtAuthGuard)
  @Delete('leaves/:id')
  async deleteLeave(@Param('id') id: string) {
    return this.salaryService.deleteLeave(id);
  }

  // --- Adjustments ---
  @UseGuards(JwtAuthGuard)
  @Get('adjustments/:userId')
  async getAdjustments(
    @Param('userId') userId: string,
    @Query('month') month: string,
    @Query('year') year: string,
  ) {
    const targetMonth = month ? parseInt(month, 10) : undefined;
    const targetYear = year ? parseInt(year, 10) : undefined;
    return this.salaryService.getAdjustments(userId, targetMonth, targetYear);
  }

  @UseGuards(JwtAuthGuard)
  @Post('adjustments')
  async addAdjustment(@Body() dto: CreateAdjustmentDto, @Request() req: any) {
    return this.salaryService.addAdjustment(dto, req.user.id);
  }
}
