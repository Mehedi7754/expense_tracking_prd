import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';

export type UploadCategory = 'receipts' | 'avatars' | 'projects';

@Injectable()
export class UploadsService {
  private readonly logger = new Logger(UploadsService.name);
  private readonly uploadsRoot: string;

  // Maximum file size: 10 MB
  private static readonly MAX_FILE_SIZE = 10 * 1024 * 1024;

  // Allowed MIME types for image uploads
  private static readonly ALLOWED_MIME_TYPES = new Set([
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
  ]);

  constructor() {
    this.uploadsRoot = process.env.UPLOADS_DIR || path.join(process.cwd(), 'uploads');
    this.ensureDirectories();
  }

  /**
   * Creates the uploads directory structure if it doesn't exist.
   */
  private ensureDirectories(): void {
    const categories: UploadCategory[] = ['receipts', 'avatars', 'projects'];
    for (const cat of categories) {
      try {
        const dir = path.join(this.uploadsRoot, cat);
        if (!fs.existsSync(dir)) {
          fs.mkdirSync(dir, { recursive: true });
          this.logger.log(`Created uploads directory: ${dir}`);
        }
      } catch (err: any) {
        this.logger.warn(`Could not create uploads directory for ${cat}: ${err.message}`);
      }
    }
  }

  /**
   * Saves an uploaded file (from base64 data URI or raw base64) to disk.
   * Returns the public URL path for the saved file.
   */
  async saveFile(
    base64Data: string,
    category: UploadCategory,
    entityId?: string,
  ): Promise<{ url: string; filename: string; sizeBytes: number }> {
    // 1. Parse the base64 data
    let buffer: Buffer;
    let extension = 'jpg';
    let mimeType = 'image/jpeg';

    if (base64Data.startsWith('data:')) {
      // Data URI format: data:image/png;base64,iVBOR...
      const match = base64Data.match(/^data:(image\/\w+);base64,(.+)$/);
      if (!match) {
        throw new BadRequestException('Invalid data URI format. Expected data:image/<type>;base64,<data>');
      }
      mimeType = match[1];
      buffer = Buffer.from(match[2], 'base64');
      extension = this.mimeToExtension(mimeType);
    } else {
      // Raw base64 string
      buffer = Buffer.from(base64Data, 'base64');
    }

    // 2. Validate MIME type
    if (!UploadsService.ALLOWED_MIME_TYPES.has(mimeType)) {
      throw new BadRequestException(
        `Unsupported file type: ${mimeType}. Allowed: ${[...UploadsService.ALLOWED_MIME_TYPES].join(', ')}`,
      );
    }

    // 3. Validate file size
    if (buffer.length > UploadsService.MAX_FILE_SIZE) {
      throw new BadRequestException(
        `File too large (${(buffer.length / 1024 / 1024).toFixed(1)} MB). Maximum: ${UploadsService.MAX_FILE_SIZE / 1024 / 1024} MB`,
      );
    }

    // 4. Generate unique filename
    const hash = crypto.createHash('sha256').update(buffer).digest('hex').substring(0, 12);
    const timestamp = Date.now();
    const prefix = entityId ? `${entityId.substring(0, 8)}_` : '';
    const filename = `${prefix}${timestamp}_${hash}.${extension}`;

    // 5. Write to disk
    const filePath = path.join(this.uploadsRoot, category, filename);
    await fs.promises.writeFile(filePath, buffer);

    // 6. Return public URL path (relative to API base)
    const url = `/uploads/${category}/${filename}`;
    this.logger.log(`Saved ${category} upload: ${filename} (${(buffer.length / 1024).toFixed(1)} KB)`);

    return {
      url,
      filename,
      sizeBytes: buffer.length,
    };
  }

  /**
   * Deletes a previously uploaded file.
   */
  async deleteFile(category: UploadCategory, filename: string): Promise<boolean> {
    const safeFilename = path.basename(filename);
    const filePath = path.join(this.uploadsRoot, category, safeFilename);
    try {
      if (fs.existsSync(filePath)) {
        await fs.promises.unlink(filePath);
        this.logger.log(`Deleted upload: ${category}/${safeFilename}`);
        return true;
      }
    } catch (e) {
      this.logger.warn(`Failed to delete upload ${category}/${safeFilename}: ${e}`);
    }
    return false;
  }

  /**
   * Maps MIME type to file extension.
   */
  private mimeToExtension(mime: string): string {
    switch (mime) {
      case 'image/png': return 'png';
      case 'image/webp': return 'webp';
      case 'image/gif': return 'gif';
      case 'image/jpeg':
      default: return 'jpg';
    }
  }
}
