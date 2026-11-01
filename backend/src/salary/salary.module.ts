import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { SalaryController } from './salary.controller';
import { SalaryService } from './salary.service';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [DatabaseModule, NotificationsModule],
  controllers: [SalaryController],
  providers: [SalaryService],
  exports: [SalaryService],
})
export class SalaryModule {}
