import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { UsersService } from './users.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@UseGuards(JwtAuthGuard)
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
}
