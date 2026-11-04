import { Module } from '@nestjs/common';
import { AppReleasesController } from './app-releases.controller';
import { AppReleasesService } from './app-releases.service';

@Module({
  controllers: [AppReleasesController],
  providers: [AppReleasesService],
  exports: [AppReleasesService],
})
export class AppReleasesModule {}
