import { Injectable, NotFoundException, BadRequestException, Logger } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import * as fs from 'fs';
import * as path from 'path';

export interface CreateReleaseDto {
  versionName: string;
  buildNumber: number;
  releaseNotes?: string;
  downloadUrl?: string;
  fileSizeBytes?: number;
  isLatest?: boolean;
}

@Injectable()
export class AppReleasesService {
  private readonly logger = new Logger(AppReleasesService.name);
  private readonly releasesDir: string;

  constructor(private readonly db: DatabaseService) {
    this.releasesDir = path.join(process.cwd(), 'uploads', 'apps');
    if (!fs.existsSync(this.releasesDir)) {
      try {
        fs.mkdirSync(this.releasesDir, { recursive: true });
      } catch (err) {
        this.logger.error('Failed to create apps release directory', err);
      }
    }
  }

  async getLatestRelease() {
    const res = await this.db.query(
      `SELECT r.id, r.version_name, r.build_number, r.release_notes, r.file_path, r.download_url, r.file_size_bytes, r.is_latest, r.created_at,
              u.full_name as created_by_name
       FROM app_releases r
       LEFT JOIN users u ON u.id = r.created_by
       WHERE r.is_latest = TRUE
       ORDER BY r.created_at DESC
       LIMIT 1`,
    );

    if (!res.rows.length) {
      return {
        id: 'default',
        versionName: 'v1.0.0',
        buildNumber: 1,
        releaseNotes: 'Initial production release of Geospatial Works Mobile App for Android.',
        downloadUrl: '/api/v1/app-releases/download-latest',
        fileSizeBytes: 28500000,
        isLatest: true,
        createdAt: new Date().toISOString(),
      };
    }

    const r = res.rows[0];
    return {
      id: r.id,
      versionName: r.version_name,
      buildNumber: r.build_number,
      releaseNotes: r.release_notes,
      filePath: r.file_path,
      downloadUrl: r.download_url || '/api/v1/app-releases/download-latest',
      fileSizeBytes: Number(r.file_size_bytes || 0),
      isLatest: r.is_latest,
      createdAt: r.created_at,
      createdByName: r.created_by_name,
    };
  }

  async getAllReleases() {
    const res = await this.db.query(
      `SELECT r.id, r.version_name, r.build_number, r.release_notes, r.file_path, r.download_url, r.file_size_bytes, r.is_latest, r.created_at,
              u.full_name as created_by_name
       FROM app_releases r
       LEFT JOIN users u ON u.id = r.created_by
       ORDER BY r.created_at DESC`,
    );

    return res.rows.map((r: any) => ({
      id: r.id,
      versionName: r.version_name,
      buildNumber: r.build_number,
      releaseNotes: r.release_notes,
      filePath: r.file_path,
      downloadUrl: r.download_url,
      fileSizeBytes: Number(r.file_size_bytes || 0),
      isLatest: r.is_latest,
      createdAt: r.created_at,
      createdByName: r.created_by_name,
    }));
  }

  async createRelease(dto: CreateReleaseDto, adminUserId?: string) {
    if (!dto.versionName) {
      throw new BadRequestException('Version name is required (e.g. v1.0.1)');
    }
    const buildNumber = Number(dto.buildNumber) || 1;
    const isLatest = dto.isLatest !== false;

    if (isLatest) {
      await this.db.query('UPDATE app_releases SET is_latest = FALSE WHERE is_latest = TRUE');
    }

    const res = await this.db.query(
      `INSERT INTO app_releases (version_name, build_number, release_notes, file_path, download_url, file_size_bytes, is_latest, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING *`,
      [
        dto.versionName.trim(),
        buildNumber,
        dto.releaseNotes || 'Bug fixes and performance improvements.',
        'uploads/apps/geospatial-works.apk',
        dto.downloadUrl || '/api/v1/app-releases/download-latest',
        dto.fileSizeBytes || 0,
        isLatest,
        adminUserId || null,
      ],
    );

    return res.rows[0];
  }

  async deleteRelease(id: string) {
    await this.db.query('DELETE FROM app_releases WHERE id::text = $1', [id]);
    return { success: true };
  }
}
