import { Controller, Get, Post, Put, Patch, Param, Body, Query, UseGuards, Request } from '@nestjs/common';
import { TasksService } from './tasks.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@UseGuards(JwtAuthGuard)
@Controller('tasks')
export class TasksController {
  constructor(private readonly tasksService: TasksService) {}

  @Get()
  async getTasks(@Query('projectId') projectId: string) {
    return this.tasksService.findAll(projectId);
  }

  @Post()
  async createTask(@Body() body: any, @Request() req: any) {
    return this.tasksService.create(body, req.user);
  }

  @Put(':id')
  async updateTask(@Param('id') id: string, @Body() body: any) {
    return this.tasksService.update(id, body);
  }

  @Patch(':id')
  async patchTask(@Param('id') id: string, @Body() body: any) {
    return this.tasksService.update(id, body);
  }
}

