import {
  Controller,
  Get,
  Post,
  Put,
  Param,
  Body,
  UseGuards,
  Request,
} from '@nestjs/common';
import { ProjectsService } from './projects.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@UseGuards(JwtAuthGuard)
@Controller('projects')
export class ProjectsController {
  constructor(private readonly projectsService: ProjectsService) {}

  @Get()
  async getProjects(@Request() req: any) {
    return this.projectsService.findAll(req.user);
  }

  @Get(':id')
  async getProject(@Param('id') id: string) {
    return this.projectsService.findOne(id);
  }

  @Post()
  async createProject(@Body() body: any, @Request() req: any) {
    return this.projectsService.create(body, req.user.id);
  }

  @Put(':id')
  async updateProject(@Param('id') id: string, @Body() body: any) {
    return this.projectsService.update(id, body);
  }

  @Post(':id/revenue')
  async addRevenue(
    @Param('id') id: string,
    @Body() body: any,
    @Request() req: any,
  ) {
    return this.projectsService.addRevenue(id, body, req.user.id);
  }

  @Post(':id/close')
  async closeProject(@Param('id') id: string, @Body() body: any) {
    return this.projectsService.closeProject(id, body);
  }
}
