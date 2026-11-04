import { Controller, Get, Post, Patch, Delete, Body, Param, UseGuards, Request, Res } from '@nestjs/common';
import { AppReleasesService } from './app-releases.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { FastifyReply } from 'fastify';
import * as fs from 'fs';
import * as path from 'path';

@Controller('app-releases')
export class AppReleasesController {
  constructor(private readonly releasesService: AppReleasesService) {}

  // Public endpoint: get current active release info
  @Get('latest')
  async getLatest() {
    return this.releasesService.getLatestRelease();
  }

  // Public endpoint: dynamic direct download link
  @Get('download-latest')
  async downloadLatest(@Res() reply: FastifyReply) {
    const latest = await this.releasesService.getLatestRelease();
    
    // Check if a local physical APK exists on server
    const localApkPath = path.join(process.cwd(), 'uploads', 'apps', 'geospatial-works.apk');
    if (fs.existsSync(localApkPath)) {
      const stream = fs.createReadStream(localApkPath);
      return reply
        .header('Content-Type', 'application/vnd.android.package-archive')
        .header('Content-Disposition', `attachment; filename="geospatial-works-${latest.versionName || 'latest'}.apk"`)
        .send(stream);
    }

    // Check PostgreSQL database fallback for zero-loss redeployment
    try {
      const dbFile = await this.releasesService.getApkFromDatabase();
      if (dbFile && dbFile.length > 0) {
        return reply
          .header('Content-Type', 'application/vnd.android.package-archive')
          .header('Content-Disposition', `attachment; filename="geospatial-works-${latest.versionName || 'latest'}.apk"`)
          .send(dbFile);
      }
    } catch (_) {}

    // If downloadUrl is an external link (e.g. S3 / CDN / GitHub releases), redirect directly
    if (latest.downloadUrl && latest.downloadUrl.startsWith('http')) {
      return reply.redirect(latest.downloadUrl, 302);
    }

    const portalUrl = process.env.APP_DOWNLOAD_PORTAL_URL || process.env.FRONTEND_URL;
    if (portalUrl) {
      return reply.redirect(`${portalUrl.replace(/\/+$/, '')}/download`, 302);
    }

    return reply.status(404).send({
      statusCode: 404,
      error: 'Not Found',
      message: 'APK package file is not currently available for download on this server.',
    });
  }

  // Public endpoint: download specific release APK by release id
  @Get(':id/download')
  async downloadRelease(@Param('id') id: string, @Res() reply: FastifyReply) {
    if (id === 'latest') {
      return this.downloadLatest(reply);
    }

    const item = await this.releasesService.getReleaseDownload(id);
    if (!item) {
      const portalUrl = process.env.APP_DOWNLOAD_PORTAL_URL || process.env.FRONTEND_URL;
      if (portalUrl) {
        return reply.redirect(`${portalUrl.replace(/\/+$/, '')}/download`, 302);
      }
      return reply.status(404).send({
        statusCode: 404,
        error: 'Not Found',
        message: `APK package file not found for release ${id}`,
      });
    }

    if (item.stream) {
      return reply
        .header('Content-Type', 'application/vnd.android.package-archive')
        .header('Content-Disposition', `attachment; filename="${item.filename}"`)
        .send(item.stream);
    }

    if (item.buffer && item.buffer.length > 0) {
      return reply
        .header('Content-Type', 'application/vnd.android.package-archive')
        .header('Content-Disposition', `attachment; filename="${item.filename}"`)
        .send(item.buffer);
    }

    if (item.redirectUrl) {
      return reply.redirect(item.redirectUrl, 302);
    }

    const portalUrl = process.env.APP_DOWNLOAD_PORTAL_URL || process.env.FRONTEND_URL;
    if (portalUrl) {
      return reply.redirect(`${portalUrl.replace(/\/+$/, '')}/download`, 302);
    }

    return reply.status(404).send({
      statusCode: 404,
      error: 'Not Found',
      message: `APK package file not found for release ${id}`,
    });
  }


  // Protected Admin endpoints
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('main_admin', 'admin')
  @Get()
  async getAll() {
    return this.releasesService.getAllReleases();
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('main_admin', 'admin')
  @Post()
  async create(@Body() body: any, @Request() req: any) {
    return this.releasesService.createRelease(body, req.user?.id);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('main_admin', 'admin')
  @Patch(':id/set-latest')
  async setLatestPatch(@Param('id') id: string) {
    return this.releasesService.setLatestRelease(id);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('main_admin', 'admin')
  @Post(':id/set-latest')
  async setLatestPost(@Param('id') id: string) {
    return this.releasesService.setLatestRelease(id);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('main_admin', 'admin')
  @Post(':id/upload-chunk')
  async uploadChunk(
    @Param('id') id: string,
    @Body() body: { chunkIndex: number; totalChunks: number; chunkBase64: string },
  ) {
    return this.releasesService.appendChunk(id, body.chunkIndex, body.totalChunks, body.chunkBase64);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('main_admin', 'admin')
  @Delete(':id')
  async delete(@Param('id') id: string) {
    return this.releasesService.deleteRelease(id);
  }
}


