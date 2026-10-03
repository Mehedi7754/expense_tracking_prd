import {
  Controller,
  Get,
  Post,
  Put,
  Patch,
  Delete,
  Param,
  Body,
  Query,
  UseGuards,
  Request,
} from '@nestjs/common';
import { UsersService } from './users.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get()
  async getUsers(@Query('q') q?: string) {
    return this.usersService.findAll(q);
  }

  @Get('search')
  async searchUsers(@Query('email') email?: string, @Query('q') q?: string) {
    if (email) {
      const user = await this.usersService.findByEmail(email);
      return user ? [user] : [];
    }
    return this.usersService.findAll(q);
  }

  @Get(':id')
  async getUser(@Param('id') id: string) {
    return this.usersService.findOne(id);
  }

  @Roles('main_admin', 'project_manager')
  @Post()
  async createUser(@Body() body: any, @Request() req: any) {
    return this.usersService.create(body, req.user);
  }

  @Roles('main_admin', 'project_manager')
  @Put(':id')
  async updateUser(@Param('id') id: string, @Body() body: any, @Request() req: any) {
    return this.usersService.update(id, body, req.user);
  }

  @Roles('main_admin')
  @Patch(':id/role')
  async updateRole(@Param('id') id: string, @Body('role') role: string) {
    return this.usersService.updateRole(id, role);
  }

  @Roles('main_admin')
  @Patch(':id/status')
  async updateStatus(@Param('id') id: string, @Body('isActive') isActive: boolean) {
    return this.usersService.updateStatus(id, isActive);
  }

  @Roles('main_admin')
  @Delete(':id')
  async deleteUser(@Param('id') id: string) {
    return this.usersService.delete(id);
  }
}
