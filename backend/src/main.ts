import { NestFactory } from '@nestjs/core';
import { FastifyAdapter, NestFastifyApplication } from '@nestjs/platform-fastify';
import { ValidationPipe, Logger } from '@nestjs/common';
import { AppModule } from './app.module';
import * as path from 'path';

async function bootstrap() {
  const logger = new Logger('Bootstrap');
  const app = await NestFactory.create<NestFastifyApplication>(
    AppModule,
    new FastifyAdapter({
      logger: false,
      // Increase body size limit for base64 image uploads (15 MB)
      bodyLimit: 15 * 1024 * 1024,
    }),
  );

  // CORS: restrict origins in production, allow all in development
  const corsOrigins = process.env.CORS_ORIGINS;
  app.enableCors({
    origin: corsOrigins ? corsOrigins.split(',').map(o => o.trim()) : '*',
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE',
    allowedHeaders: 'Content-Type, Accept, Authorization, Host, X-Client-Platform, X-Client-Environment',
    credentials: true,
  });

  app.setGlobalPrefix('api/v1');

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: false,
    }),
  );

  // Serve uploaded files as static assets at /uploads/*
  const uploadsDir = process.env.UPLOADS_DIR || path.join(process.cwd(), 'uploads');
  app.useStaticAssets({
    root: uploadsDir,
    prefix: '/uploads/',
    decorateReply: false,
  });

  const port = Number(process.env.PORT) || 8080;
  const host = process.env.HOST || '0.0.0.0';

  await app.listen(port, host);
  logger.log(`GW Project NestJS Backend running at http://${host}:${port}/api/v1`);
  logger.log(`Static uploads served from: ${uploadsDir}`);
}
bootstrap();
