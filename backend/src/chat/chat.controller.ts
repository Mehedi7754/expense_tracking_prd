import {
  Controller,
  Get,
  Post,
  Param,
  Body,
  Query,
  UseGuards,
  Request,
  BadRequestException,
} from '@nestjs/common';
import { ChatService } from './chat.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@UseGuards(JwtAuthGuard)
@Controller('chat')
export class ChatController {
  constructor(private readonly chatService: ChatService) {}

  @Get('channels')
  async getChannels(@Request() req: any) {
    return this.chatService.getUserChannels(req.user.id);
  }

  @Post('channels/direct')
  async getOrCreateDirectChannel(@Request() req: any, @Body() body: { recipientId: string }) {
    if (!body.recipientId) {
      throw new BadRequestException('recipientId is required');
    }
    return this.chatService.getOrCreateDirectChannel(req.user.id, body.recipientId);
  }

  @Post('channels/project')
  async getOrCreateProjectChannel(@Request() req: any, @Body() body: { projectId: string }) {
    if (!body.projectId) {
      throw new BadRequestException('projectId is required');
    }
    return this.chatService.getOrCreateProjectChannel(req.user.id, body.projectId);
  }

  @Get('channels/:id/messages')
  async getMessages(
    @Request() req: any,
    @Param('id') channelId: string,
    @Query('limit') limit?: string,
  ) {
    const lim = limit ? parseInt(limit, 10) : 50;
    return this.chatService.getChannelMessages(channelId, req.user.id, lim);
  }

  @Post('channels/:id/messages')
  async sendMessage(
    @Request() req: any,
    @Param('id') channelId: string,
    @Body() body: { content?: string; imageUrl?: string; projectId?: string },
  ) {
    return this.chatService.sendMessage(
      req.user.id,
      channelId,
      body.content || '',
      body.imageUrl,
      body.projectId,
    );
  }

  @Post('channels/:id/read')
  async markRead(@Request() req: any, @Param('id') channelId: string) {
    return this.chatService.markChannelAsRead(channelId, req.user.id);
  }

  @Get('unread-count')
  async getUnreadCount(@Request() req: any) {
    const count = await this.chatService.getTotalUnreadCount(req.user.id);
    return { unreadCount: count };
  }

  @Post('upload')
  async uploadPhoto(@Body() body: { file: string }) {
    if (!body.file || body.file.trim().length === 0) {
      throw new BadRequestException('Missing required field: file (base64 data)');
    }
    const result = await this.chatService.uploadChatPhoto(body.file);
    return {
      success: true,
      url: result.url,
      filename: result.filename,
    };
  }
}
