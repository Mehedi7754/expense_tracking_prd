import {
  Controller,
  Get,
  Post,
  Put,
  Patch,
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

  @Get(':id/members')
  async getMembers(@Param('id') id: string) {
    return this.projectsService.getProjectMembers(id);
  }

  @Get(':id/my-permissions')
  async getMyPermissions(@Param('id') id: string, @Request() req: any) {
    return this.projectsService.getMyProjectPermissions(id, req.user);
  }

  @Post(':id/members')
  async addMember(
    @Param('id') id: string,
    @Body() body: any,
    @Request() req: any,
  ) {
    return this.projectsService.addOrUpdateProjectMember(id, body, req.user);
  }

  @Patch(':id/members/:userId')
  async updateMember(
    @Param('id') id: string,
    @Param('userId') userId: string,
    @Body() body: any,
    @Request() req: any,
  ) {
    return this.projectsService.addOrUpdateProjectMember(id, { ...body, userId }, req.user);
  }

  @Delete(':id/members/:userId')
  async removeMember(
    @Param('id') id: string,
    @Param('userId') userId: string,
    @Request() req: any,
  ) {
    return this.projectsService.removeProjectMember(id, userId, req.user);
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

  @Post(':id/notes')
  async addProjectNote(@Param('id') id: string, @Body() body: any, @Request() req: any) {
    return this.projectsService.addProjectNote(id, body.note, req.user);
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

