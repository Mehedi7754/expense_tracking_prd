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
  apkBase64?: string;
  apkFileName?: string;
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
    let calculatedSizeBytes = dto.fileSizeBytes || 0;
    const cleanVersion = dto.versionName.trim();
    const versionApkFileName = `geospatial-works-${cleanVersion}.apk`;
    const versionFilePath = path.join(this.releasesDir, versionApkFileName);
    const latestFilePath = path.join(this.releasesDir, 'geospatial-works.apk');

    if (isLatest) {
      await this.db.query('UPDATE app_releases SET is_latest = FALSE WHERE is_latest = TRUE');
    }

    const res = await this.db.query(
      `INSERT INTO app_releases (version_name, build_number, release_notes, file_path, download_url, file_size_bytes, is_latest, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING *`,
      [
        cleanVersion,
        buildNumber,
        dto.releaseNotes || 'Bug fixes and performance improvements.',
        `uploads/apps/${versionApkFileName}`,
        dto.downloadUrl || '/api/v1/app-releases/download-latest',
        calculatedSizeBytes,
        isLatest,
        adminUserId || null,
      ],
    );

    const created = res.rows[0];

    if (dto.apkBase64) {
      try {
        let cleanBase64 = dto.apkBase64;
        if (cleanBase64.startsWith('data:')) {
          const commaIdx = cleanBase64.indexOf(',');
          if (commaIdx !== -1) cleanBase64 = cleanBase64.substring(commaIdx + 1);
        }
        const buffer = Buffer.from(cleanBase64, 'base64');
        calculatedSizeBytes = buffer.length;

        // Save versioned physical APK
        await fs.promises.writeFile(versionFilePath, buffer);
        this.logger.log(`Saved versioned physical APK (${calculatedSizeBytes} bytes) to ${versionFilePath}`);

        // If marked latest, also update geospatial-works.apk
        if (isLatest) {
          await fs.promises.copyFile(versionFilePath, latestFilePath);
        }

        // Persist into app_uploaded_files for persistence across redeploys
        await this.db.query(
          `INSERT INTO app_uploaded_files (id, filename, category, mime_type, file_size, data_base64)
           VALUES ($1, $2, $3, $4, $5, $6)
           ON CONFLICT (id) DO UPDATE 
           SET data_base64 = EXCLUDED.data_base64, file_size = EXCLUDED.file_size, updated_at = NOW()`,
          [
            `apk_release_${created.id}`,
            versionApkFileName,
            'apps',
            'application/vnd.android.package-archive',
            calculatedSizeBytes,
            cleanBase64,
          ],
        ).catch((err) => this.logger.warn(`Could not save versioned APK to DB: ${err.message}`));

        if (isLatest) {
          await this.db.query(
            `INSERT INTO app_uploaded_files (id, filename, category, mime_type, file_size, data_base64)
             VALUES ($1, $2, $3, $4, $5, $6)
             ON CONFLICT (id) DO UPDATE 
             SET data_base64 = EXCLUDED.data_base64, file_size = EXCLUDED.file_size, updated_at = NOW()`,
            [
              'apk_latest_binary',
              'geospatial-works.apk',
              'apps',
              'application/vnd.android.package-archive',
              calculatedSizeBytes,
              cleanBase64,
            ],
          ).catch((err) => this.logger.warn(`Could not mirror latest APK to DB: ${err.message}`));
        }

        // Update file size in release record if it was calculated from binary
        await this.db.query('UPDATE app_releases SET file_size_bytes = $1 WHERE id = $2', [
          calculatedSizeBytes,
          created.id,
        ]);
        created.file_size_bytes = calculatedSizeBytes;
      } catch (err: any) {
        this.logger.error(`Failed to write uploaded APK file: ${err.message}`);
      }
    }

    return created;
  }

  async setLatestRelease(id: string) {
    const existing = await this.db.query('SELECT * FROM app_releases WHERE id::text = $1', [id]);
    if (!existing.rows.length) {
      throw new NotFoundException(`Release with ID ${id} not found`);
    }
    const target = existing.rows[0];

    // Unmark all others
    await this.db.query('UPDATE app_releases SET is_latest = FALSE WHERE is_latest = TRUE');

    // Mark target as latest
    const res = await this.db.query(
      'UPDATE app_releases SET is_latest = TRUE WHERE id::text = $1 RETURNING *',
      [id],
    );

    // Sync physical files
    const versionApkFileName = `geospatial-works-${target.version_name}.apk`;
    const versionFilePath = path.join(this.releasesDir, versionApkFileName);
    const latestFilePath = path.join(this.releasesDir, 'geospatial-works.apk');

    if (fs.existsSync(versionFilePath)) {
      try {
        await fs.promises.copyFile(versionFilePath, latestFilePath);
        this.logger.log(`Copied ${versionFilePath} to ${latestFilePath} as new latest release`);
      } catch (err: any) {
        this.logger.warn(`Failed to copy versioned APK to latest: ${err.message}`);
      }
    }

    // Sync DB binary
    try {
      const dbFile = await this.db.query(
        `SELECT * FROM app_uploaded_files WHERE id = $1`,
        [`apk_release_${id}`],
      );
      if (dbFile.rows.length && dbFile.rows[0].data_base64) {
        await this.db.query(
          `INSERT INTO app_uploaded_files (id, filename, category, mime_type, file_size, data_base64)
           VALUES ('apk_latest_binary', 'geospatial-works.apk', 'apps', 'application/vnd.android.package-archive', $1, $2)
           ON CONFLICT (id) DO UPDATE 
           SET data_base64 = EXCLUDED.data_base64, file_size = EXCLUDED.file_size, updated_at = NOW()`,
          [dbFile.rows[0].file_size, dbFile.rows[0].data_base64],
        );
      }
    } catch (err: any) {
      this.logger.warn(`Could not sync DB apk_latest_binary: ${err.message}`);
    }

    return res.rows[0];
  }

  async getReleaseDownload(id: string): Promise<{
    stream?: fs.ReadStream;
    buffer?: Buffer;
    filename: string;
    redirectUrl?: string;
  } | null> {
    const res = await this.db.query('SELECT * FROM app_releases WHERE id::text = $1', [id]);
    if (!res.rows.length) {
      return null;
    }
    const r = res.rows[0];
    const filename = `geospatial-works-${r.version_name || id}.apk`;

    // 1. Check physical versioned file
    const versionFilePath = path.join(this.releasesDir, `geospatial-works-${r.version_name}.apk`);
    if (fs.existsSync(versionFilePath)) {
      return { stream: fs.createReadStream(versionFilePath), filename };
    }

    // 2. If it's latest, check geospatial-works.apk
    const latestFilePath = path.join(this.releasesDir, 'geospatial-works.apk');
    if (r.is_latest && fs.existsSync(latestFilePath)) {
      return { stream: fs.createReadStream(latestFilePath), filename };
    }

    // 3. Check DB for specific release
    try {
      const dbFile = await this.db.query(
        `SELECT data_base64 FROM app_uploaded_files WHERE id = $1 LIMIT 1`,
        [`apk_release_${id}`],
      );
      if (dbFile.rows.length && dbFile.rows[0].data_base64) {
        let b64 = dbFile.rows[0].data_base64 as string;
        if (b64.startsWith('data:')) {
          const idx = b64.indexOf(',');
          if (idx !== -1) b64 = b64.substring(idx + 1);
        }
        return { buffer: Buffer.from(b64, 'base64'), filename };
      }
    } catch (_) {}

    // 4. If latest, check DB latest
    if (r.is_latest) {
      const dbLatest = await this.getApkFromDatabase();
      if (dbLatest) {
        return { buffer: dbLatest, filename };
      }
    }

    // 5. External URL
    if (r.download_url && r.download_url.startsWith('http')) {
      return { redirectUrl: r.download_url, filename };
    }

    return null;
  }

  async deleteRelease(id: string) {
    await this.db.query('DELETE FROM app_releases WHERE id::text = $1', [id]);
    await this.db.query('DELETE FROM app_uploaded_files WHERE id = $1', [`apk_release_${id}`]).catch(() => {});
    return { success: true };
  }

  async getApkFromDatabase(): Promise<Buffer | null> {
    const res = await this.db.query(
      `SELECT data_base64 FROM app_uploaded_files WHERE id = 'apk_latest_binary' OR category = 'apps' LIMIT 1`,
    );
    if (!res.rows.length) return null;
    let b64 = res.rows[0].data_base64 as string;
    if (b64.startsWith('data:')) {
      const idx = b64.indexOf(',');
      if (idx !== -1) b64 = b64.substring(idx + 1);
    }
    return Buffer.from(b64, 'base64');
  }
}

