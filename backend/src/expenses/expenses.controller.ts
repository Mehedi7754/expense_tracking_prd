import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Param,
  Body,
  Query,
  UseGuards,
  Request,
} from '@nestjs/common';
import { ExpensesService } from './expenses.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@UseGuards(JwtAuthGuard)
@Controller('expenses')
export class ExpensesController {
  constructor(private readonly expensesService: ExpensesService) {}

  @Get()
  async getExpenses(
    @Query('projectId') projectId: string,
    @Query('employeeId') employeeId: string,
    @Query('status') status: string,
    @Request() req: any,
  ) {
    return this.expensesService.findAll({ projectId, employeeId, status }, req.user);
  }

  @Get(':id')
  async getExpense(@Param('id') id: string) {
    return this.expensesService.findOne(id);
  }

  @Post()
  async createExpense(@Body() body: any, @Request() req: any) {
    return this.expensesService.create(body, req.user);
  }

  @Put(':id')
  async updateExpense(@Param('id') id: string, @Body() body: any) {
    return this.expensesService.update(id, body);
  }

  @Delete(':id')
  async deleteExpense(@Param('id') id: string) {
    return this.expensesService.delete(id);
  }

  @Post(':id/approve')
  async approveExpense(
    @Param('id') id: string,
    @Body('note') note: string,
    @Request() req: any,
  ) {
    return this.expensesService.approve(id, req.user.id, note);
  }

  @Post(':id/reject')
  async rejectExpense(
    @Param('id') id: string,
    @Body('reason') reason: string,
    @Request() req: any,
  ) {
    return this.expensesService.reject(id, req.user.id, reason);
  }

  @Post(':id/comments')
  async addComment(
    @Param('id') id: string,
    @Body('comment') comment: string,
    @Request() req: any,
  ) {
    return this.expensesService.addComment(id, req.user.id, comment);
  }
}
