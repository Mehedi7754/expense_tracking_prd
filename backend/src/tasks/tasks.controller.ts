import { Controller, Get, Post, Put, Patch, Delete, Param, Body, Query, UseGuards, Request } from '@nestjs/common';
import { TasksService } from './tasks.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('tasks')
export class TasksController {
  constructor(private readonly tasksService: TasksService) {}

  @Get()
  @Roles('main_admin', 'project_manager', 'project_member')
  async getTasks(
    @Query('projectId') projectId: string,
    @Query('project_id') projectIdSnake: string,
    @Query('assigneeId') assigneeId: string,
    @Query('assignee_id') assigneeIdSnake: string,
    @Request() req: any,
  ) {
    return this.tasksService.findAll(projectId || projectIdSnake, assigneeId || assigneeIdSnake, req.user);
  }

  @Post()
  @Roles('main_admin', 'project_manager')
  async createTask(@Body() body: any, @Request() req: any) {
    return this.tasksService.create(body, req.user);
  }

  @Put(':id')
  async updateTask(@Param('id') id: string, @Body() body: any, @Request() req: any) {
    return this.tasksService.update(id, body, req.user);
  }

  @Patch(':id')
  async patchTask(@Param('id') id: string, @Body() body: any, @Request() req: any) {
    return this.tasksService.update(id, body, req.user);
  }

  @Delete(':id')
  @Roles('main_admin', 'project_manager')
  async deleteTask(@Param('id') id: string, @Request() req: any) {
    return this.tasksService.delete(id, req.user);
  }
}

