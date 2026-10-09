import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Param,
  Body,
  UseGuards,
  Request,
} from '@nestjs/common';
import { ProjectsService } from './projects.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('projects')
export class ProjectsController {
  constructor(private readonly projectsService: ProjectsService) {}

  @Get()
  async getProjects(@Request() req: any) {
    return this.projectsService.findAll(req.user);
  }

  @Get(':id')
  async getProject(@Param('id') id: string, @Request() req: any) {
    return this.projectsService.findOne(id, req.user);
  }

  @Roles('main_admin', 'project_manager')
  @Post()
  async createProject(@Body() body: any, @Request() req: any) {
    return this.projectsService.create(body, req.user.id);
  }

  @Roles('main_admin', 'project_manager')
  @Put(':id')
  async updateProject(@Param('id') id: string, @Body() body: any, @Request() req: any) {
    return this.projectsService.update(id, body, req.user);
  }

  @Roles('main_admin', 'project_manager')
  @Post(':id/revenue')
  async addRevenue(
    @Param('id') id: string,
    @Body() body: any,
    @Request() req: any,
  ) {
    return this.projectsService.addRevenue(id, body, req.user.id);
  }

  @Roles('main_admin', 'project_manager')
  @Post(':id/revenues')
  async addRevenues(
    @Param('id') id: string,
    @Body() body: any,
    @Request() req: any,
  ) {
    return this.projectsService.addRevenue(id, body, req.user.id);
  }

  @Roles('main_admin', 'project_manager')
  @Post(':id/close')
  async closeProject(@Param('id') id: string, @Body() body: any) {
    return this.projectsService.closeProject(id, body);
  }

  @Roles('main_admin', 'project_manager')
  @Post(':id/reopen')
  async reopenProject(@Param('id') id: string) {
    return this.projectsService.reopenProject(id);
  }

  @Roles('main_admin', 'project_manager')
  @Delete(':id')
  async deleteProject(@Param('id') id: string, @Request() req: any) {
    return this.projectsService.delete(id, req.user);
  }
}

