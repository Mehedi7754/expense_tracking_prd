import { NestFactory } from '@nestjs/core';
import { FastifyAdapter, NestFastifyApplication } from '@nestjs/platform-fastify';
import { ValidationPipe, Logger } from '@nestjs/common';
import { AppModule } from './app.module';
import { UploadsService } from './uploads/uploads.service';
import * as path from 'path';

async function bootstrap() {
  const logger = new Logger('Bootstrap');
  const fastifyAdapter = new FastifyAdapter({
    logger: false,
    // Increase body size limit for base64 image uploads (15 MB)
    bodyLimit: 15 * 1024 * 1024,
  });


  const app = await NestFactory.create<NestFastifyApplication>(
    AppModule,
    fastifyAdapter,
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

  // Static assets are handled by manual fastify routes below to allow DB fallback

  // Direct fastify route for /uploads/* with PostgreSQL fallback
  try {
    const fastify = app.getHttpAdapter().getInstance();
    const serveUpload = async (req: any, reply: any) => {
      const { category, filename } = req.params;
      const uploadsService = app.get(UploadsService);
      const file = await uploadsService.getFile(category, filename);
      if (!file) {
        return reply.code(404).send({ message: 'File not found', statusCode: 404 });
      }
      return reply
        .type(file.mimeType)
        .header('Cache-Control', 'public, max-age=31536000, immutable')
        .send(file.buffer);
    };
    // Direct fastify route for root /uploads/* (non-prefixed requests)
    fastify.get('/uploads/:category/:filename', serveUpload);
  } catch (_) {}

  const port = Number(process.env.PORT) || 8080;
  const host = process.env.HOST || '0.0.0.0';

  await app.listen(port, host);
  logger.log(`GW Project NestJS Backend running at http://${host}:${port}/api/v1`);
  const uploadsDir = process.env.UPLOADS_DIR || path.join(process.cwd(), 'uploads');
  logger.log(`Static uploads served from: ${uploadsDir}`);
}
bootstrap();
