import {
  Controller,
  Post,
  Get,
  Param,
  Res,
  Body,
  UseGuards,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { FastifyReply } from 'fastify';
import { UploadsService, UploadCategory } from './uploads.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

import { IsString, IsNotEmpty, IsOptional } from 'class-validator';

class UploadFileDto {
  @IsString()
  @IsNotEmpty()
  file!: string;       // base64 data URI or raw base64

  @IsString()
  @IsNotEmpty()
  category!: string;   // 'receipts' | 'avatars' | 'projects'

  @IsOptional()
  @IsString()
  entityId?: string;   // Optional: expense ID, user ID, or project ID
}

@Controller('uploads')
export class UploadsController {
  constructor(private readonly uploadsService: UploadsService) {}

  @UseGuards(JwtAuthGuard)
  @Post()
  async uploadFile(@Body() dto: UploadFileDto) {
    if (!dto.file || dto.file.trim().length === 0) {
      throw new BadRequestException('Missing required field: file (base64 data)');
    }

    const validCategories: UploadCategory[] = ['receipts', 'avatars', 'projects', 'chat'];
    const category = (dto.category || 'receipts') as UploadCategory;
    if (!validCategories.includes(category)) {
      throw new BadRequestException(
        `Invalid category: ${dto.category}. Must be one of: ${validCategories.join(', ')}`,
      );
    }

    const result = await this.uploadsService.saveFile(
      dto.file,
      category,
      dto.entityId,
    );

    return {
      success: true,
      url: result.url,
      filename: result.filename,
      sizeBytes: result.sizeBytes,
    };
  }

  @UseGuards(JwtAuthGuard)
  @Post('batch')
  async uploadBatch(@Body() body: { files: Array<string | { file: string; category?: string; entityId?: string }>; category?: string; entityId?: string }) {
    if (!body || !Array.isArray(body.files) || body.files.length === 0) {
      throw new BadRequestException('files array is required');
    }
    if (body.files.length > 20) throw new BadRequestException('A batch can contain at most 20 files');

    const validCategories: UploadCategory[] = ['receipts', 'avatars', 'projects', 'chat'];
    const results = [];

    for (const item of body.files) {
      const file = typeof item === 'string' ? item : item?.file;
      const category = (typeof item === 'string' ? body.category || 'receipts' : item?.category || body.category || 'receipts') as UploadCategory;
      const entityId = typeof item === 'string' ? body.entityId : item?.entityId || body.entityId;
      if (!file || typeof file !== 'string' || file.trim().length === 0) {
        throw new BadRequestException('Every batch item must contain a file');
      }
      if (!validCategories.includes(category)) throw new BadRequestException(`Invalid upload category: ${category}`);

      const result = await this.uploadsService.saveFile(
        file,
        category,
        entityId,
      );
      results.push({
        url: result.url,
        filename: result.filename,
        sizeBytes: result.sizeBytes,
      });
    }

    return {
      success: true,
      results,
      files: results,
      urls: results.map((r) => r.url),
    };
  }

  @Get(':category/:filename')
  async getUploadedFile(
    @Param('category') category: string,
    @Param('filename') filename: string,
    @Res() reply: FastifyReply,
  ) {
    const file = await this.uploadsService.getFile(category, filename);
    if (!file) {
      throw new NotFoundException('File not found');
    }

    reply
      .header('Content-Type', file.mimeType)
      .header('Cache-Control', 'public, max-age=31536000, immutable')
      .send(file.buffer);
  }
}
