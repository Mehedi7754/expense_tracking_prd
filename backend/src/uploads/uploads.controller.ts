import {
  Controller,
  Post,
  Body,
  UseGuards,
  BadRequestException,
} from '@nestjs/common';
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

@UseGuards(JwtAuthGuard)
@Controller('uploads')
export class UploadsController {
  constructor(private readonly uploadsService: UploadsService) {}

  @Post()
  async uploadFile(@Body() dto: UploadFileDto) {
    if (!dto.file || dto.file.trim().length === 0) {
      throw new BadRequestException('Missing required field: file (base64 data)');
    }

    const validCategories: UploadCategory[] = ['receipts', 'avatars', 'projects'];
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
}
