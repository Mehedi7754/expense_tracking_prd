import { Controller, Get, Post, Delete, Body, Param, UseGuards, Request, Res } from '@nestjs/common';
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

    // If downloadUrl is an external link (e.g. S3 / CDN / GitHub releases), redirect directly
    if (latest.downloadUrl && latest.downloadUrl.startsWith('http')) {
      return reply.redirect(latest.downloadUrl, 302);
    }

    // Default friendly fallback redirect to web download page
    return reply.redirect('https://mtoam6j7bojzuo6lhsakwfp8.203.96.190.78.sslip.io/download', 302);
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
  @Delete(':id')
  async delete(@Param('id') id: string) {
    return this.releasesService.deleteRelease(id);
  }
}
