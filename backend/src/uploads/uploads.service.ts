import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';
import { S3Client, PutObjectCommand, DeleteObjectCommand } from '@aws-sdk/client-s3';
import { DatabaseService } from '../database/database.service';

export type UploadCategory = 'receipts' | 'avatars' | 'projects' | 'chat';

@Injectable()
export class UploadsService {
  private readonly logger = new Logger(UploadsService.name);
  private readonly uploadsRoot: string;
  private s3Client?: S3Client;
  private readonly s3Bucket?: string;
  private readonly s3PublicUrlPrefix?: string;

  // Maximum file size: 10 MB
  private static readonly MAX_FILE_SIZE = 10 * 1024 * 1024;

  // Allowed MIME types for image uploads
  private static readonly ALLOWED_MIME_TYPES = new Set([
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
  ]);

  constructor(private readonly db: DatabaseService) {
    this.uploadsRoot = process.env.UPLOADS_DIR || path.join(process.cwd(), 'uploads');
    this.ensureDirectories();

    // S3 / MinIO Object Storage Configuration
    const s3Endpoint = process.env.S3_ENDPOINT || process.env.MINIO_ENDPOINT;
    const s3Region = process.env.S3_REGION || process.env.AWS_REGION || 'us-east-1';
    const s3AccessKey = process.env.S3_ACCESS_KEY_ID || process.env.MINIO_ROOT_USER || process.env.AWS_ACCESS_KEY_ID;
    const s3SecretKey = process.env.S3_SECRET_ACCESS_KEY || process.env.MINIO_ROOT_PASSWORD || process.env.AWS_SECRET_ACCESS_KEY;
    this.s3Bucket = process.env.S3_BUCKET_NAME || process.env.MINIO_BUCKET || 'gw-uploads';
    this.s3PublicUrlPrefix = process.env.S3_PUBLIC_URL_PREFIX || process.env.STORAGE_CDN_URL;

    if (s3AccessKey && s3SecretKey) {
      this.s3Client = new S3Client({
        endpoint: s3Endpoint, // e.g. http://minio:9000 or https://s3.amazonaws.com
        region: s3Region,
        credentials: {
          accessKeyId: s3AccessKey,
          secretAccessKey: s3SecretKey,
        },
        forcePathStyle: true, // Needed for MinIO and self-hosted S3
      });
      this.logger.log(`Initialized S3/MinIO Storage provider for bucket: ${this.s3Bucket} (Endpoint: ${s3Endpoint || 'AWS'})`);
    } else {
      this.logger.log('S3/MinIO credentials not provided. Using local disk / persistent volume storage.');
    }
  }

  /**
   * Creates the uploads directory structure if it doesn't exist.
   */
  private ensureDirectories(): void {
    const categories: UploadCategory[] = ['receipts', 'avatars', 'projects', 'chat'];
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
   * Saves an uploaded file (from base64 data URI or raw base64) to S3/MinIO bucket or disk.
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
    const objectKey = `${category}/${filename}`;

    // 5. Always persist to local disk as fallback/cache
    try {
      const filePath = path.join(this.uploadsRoot, category, filename);
      await fs.promises.writeFile(filePath, buffer);
    } catch (e: any) {
      this.logger.warn(`Could not write local copy of upload: ${e.message}`);
    }

    // Persist to PostgreSQL database for zero-loss redeployment durability
    try {
      await this.db.query(
        `INSERT INTO app_uploaded_files (id, category, filename, mime_type, data_base64)
         VALUES ($1, $2, $3, $4, $5)
         ON CONFLICT (filename) DO UPDATE SET data_base64 = EXCLUDED.data_base64`,
        [filename, category, filename, mimeType, base64Data],
      );
    } catch (dbErr: any) {
      this.logger.warn(`Could not write database copy of upload: ${dbErr.message}`);
    }

    // 6. If S3 / MinIO is configured, stream to object bucket
    if (this.s3Client && this.s3Bucket) {
      try {
        await this.s3Client.send(
          new PutObjectCommand({
            Bucket: this.s3Bucket,
            Key: objectKey,
            Body: buffer,
            ContentType: mimeType,
          }),
        );
        this.logger.log(`Uploaded ${objectKey} to S3/MinIO bucket (${this.s3Bucket})`);

        // If a public CDN prefix is configured (e.g. https://cdn.example.com or MinIO public endpoint)
        if (this.s3PublicUrlPrefix) {
          const publicUrl = `${this.s3PublicUrlPrefix.replace(/\/$/, '')}/${objectKey}`;
          return {
            url: publicUrl,
            filename,
            sizeBytes: buffer.length,
          };
        }
      } catch (s3Err: any) {
        this.logger.error(`Failed to upload to S3/MinIO: ${s3Err.message}`, s3Err.stack);
      }
    }

    // 7. Return local static URL path
    const url = `/uploads/${category}/${filename}`;
    this.logger.log(`Saved ${category} upload: ${filename} (${(buffer.length / 1024).toFixed(1)} KB)`);

    return {
      url,
      filename,
      sizeBytes: buffer.length,
    };
  }

  /**
   * Retrieves an uploaded file from disk cache or PostgreSQL persistent storage.
   */
  async getFile(category: string, filename: string): Promise<{ buffer: Buffer; mimeType: string } | null> {
    const safeFilename = path.basename(filename);
    const diskPath = path.join(this.uploadsRoot, category, safeFilename);

    // 1. Check disk first
    if (fs.existsSync(diskPath)) {
      try {
        const buffer = await fs.promises.readFile(diskPath);
        const ext = path.extname(safeFilename).toLowerCase().replace('.', '');
        const mimeType = ext === 'png' ? 'image/png' : ext === 'gif' ? 'image/gif' : ext === 'webp' ? 'image/webp' : 'image/jpeg';
        return { buffer, mimeType };
      } catch (_) {}
    }

    // 2. Fall back to PostgreSQL database
    try {
      const res = await this.db.query(
        `SELECT mime_type, data_base64 FROM app_uploaded_files WHERE filename = $1 OR id = $1 LIMIT 1`,
        [safeFilename],
      );
      if (res.rows.length > 0) {
        const row = res.rows[0];
        let base64 = row.data_base64 as string;
        if (base64.startsWith('data:')) {
          const commaIdx = base64.indexOf(',');
          if (commaIdx !== -1) base64 = base64.substring(commaIdx + 1);
        }
        const buffer = Buffer.from(base64, 'base64');
        // Restore to disk cache
        try {
          const dir = path.join(this.uploadsRoot, category);
          if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
          await fs.promises.writeFile(diskPath, buffer);
        } catch (_) {}
        return { buffer, mimeType: row.mime_type || 'image/jpeg' };
      }
    } catch (e: any) {
      this.logger.warn(`Could not fetch file from database: ${e.message}`);
    }

    return null;
  }

  /**
   * Deletes a previously uploaded file from both S3 and local storage.
   */
  async deleteFile(category: UploadCategory, filename: string): Promise<boolean> {
    const safeFilename = path.basename(filename);
    const objectKey = `${category}/${safeFilename}`;

    // 1. Delete from S3 if configured
    if (this.s3Client && this.s3Bucket) {
      try {
        await this.s3Client.send(
          new DeleteObjectCommand({
            Bucket: this.s3Bucket,
            Key: objectKey,
          }),
        );
        this.logger.log(`Deleted S3/MinIO object: ${objectKey}`);
      } catch (s3Err: any) {
        this.logger.warn(`Failed to delete S3/MinIO object ${objectKey}: ${s3Err.message}`);
      }
    }

    // 2. Delete from local disk
    const filePath = path.join(this.uploadsRoot, category, safeFilename);
    try {
      if (fs.existsSync(filePath)) {
        await fs.promises.unlink(filePath);
        this.logger.log(`Deleted local upload: ${category}/${safeFilename}`);
        return true;
      }
    } catch (e: any) {
      this.logger.warn(`Failed to delete upload ${category}/${safeFilename}: ${e.message}`);
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
