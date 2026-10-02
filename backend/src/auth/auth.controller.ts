import { Controller, Post, Get, Patch, Put, Body, UseGuards, Request, HttpCode, HttpStatus } from '@nestjs/common';
import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { JwtAuthGuard } from './jwt-auth.guard';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @HttpCode(HttpStatus.OK)
  @Post('login')
  async login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @Post('register')
  async register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me')
  async getProfile(@Request() req: any) {
    return req.user;
  }

  @UseGuards(JwtAuthGuard)
  @Patch('profile')
  async updateProfile(@Body() body: any, @Request() req: any) {
    return this.authService.updateProfile(req.user.id, body);
  }

  @UseGuards(JwtAuthGuard)
  @Put('avatar')
  async updateAvatar(@Body() body: { avatarUrl?: string; avatar_url?: string }, @Request() req: any) {
    const url = body.avatarUrl || body.avatar_url || null;
    return this.authService.updateAvatar(req.user.id, url);
  }

  @UseGuards(JwtAuthGuard)
  @Post('change-password')
  async changePassword(
    @Body() body: { currentPassword?: string; current_password?: string; oldPassword?: string; newPassword?: string; new_password?: string },
    @Request() req: any,
  ) {
    const currentPass = body.currentPassword || body.current_password || body.oldPassword || '';
    const newPass = body.newPassword || body.new_password || '';
    return this.authService.changePassword(req.user.id, currentPass, newPass);
  }
}
