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
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';

@UseGuards(JwtAuthGuard, RolesGuard)
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
  async getExpense(@Param('id') id: string, @Request() req: any) {
    return this.expensesService.findOne(id, req.user);
  }

  @Post()
  async createExpense(@Body() body: any, @Request() req: any) {
    return this.expensesService.create(body, req.user);
  }

  @Put(':id')
  async updateExpense(@Param('id') id: string, @Body() body: any, @Request() req: any) {
    return this.expensesService.update(id, body, req.user);
  }

  @Delete(':id')
  async deleteExpense(@Param('id') id: string, @Request() req: any) {
    return this.expensesService.delete(id, req.user);
  }

  @Post(':id/approve')
  async approveExpense(
    @Param('id') id: string,
    @Body('note') note: string,
    @Request() req: any,
  ) {
    return this.expensesService.approve(id, req.user.id, note, req.user);
  }

  @Post(':id/reject')
  async rejectExpense(
    @Param('id') id: string,
    @Body() body: { reason?: string; rejectionReason?: string; rejection_reason?: string },
    @Request() req: any,
  ) {
    const reason = body?.reason ?? body?.rejectionReason ?? body?.rejection_reason;
    return this.expensesService.reject(id, req.user.id, reason, req.user);
  }

  @Get(':id/comments')
  async getComments(@Param('id') id: string, @Request() req: any) {
    return this.expensesService.getComments(id, req.user);
  }

  @Post(':id/comments')
  async addComment(
    @Param('id') id: string,
    @Body() body: any,
    @Request() req: any,
  ) {
    const text = typeof body === 'string'
      ? body
      : (body?.comment ?? body?.text ?? body?.comment_text ?? '');
    return this.expensesService.addComment(id, req.user.id, text);
  }

  @Post(':id/justification')
  async submitJustification(
    @Param('id') id: string,
    @Body() body: any,
    @Request() req: any,
  ) {
    return this.expensesService.submitJustification(id, req.user.id, body);
  }

  @Roles('main_admin', 'project_manager')
  @Post(':id/justification/review')
  async reviewJustification(
    @Param('id') id: string,
    @Body() body: any,
    @Request() req: any,
  ) {
    return this.expensesService.reviewJustification(id, req.user.id, body);
  }
}

