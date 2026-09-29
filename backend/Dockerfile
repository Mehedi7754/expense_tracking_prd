# Stage 1: Build
FROM node:22-alpine AS builder

WORKDIR /usr/src/app

COPY package*.json tsconfig*.json nest-cli.json ./
RUN npm ci --quiet

COPY src/ ./src/
ENV NODE_OPTIONS="--max-old-space-size=512"
RUN npm run build

# Stage 2: Production Runner
FROM node:22-alpine AS runner

WORKDIR /usr/src/app

ENV NODE_ENV=production
ENV PORT=8080
ENV HOST=0.0.0.0

COPY package*.json ./
RUN npm ci --quiet --omit=dev && npm cache clean --force

COPY --from=builder /usr/src/app/dist ./dist

USER node

EXPOSE 8080

CMD ["node", "dist/main.js"]
