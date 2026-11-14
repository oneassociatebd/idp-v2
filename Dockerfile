ARG BUN_VERSION=1.3
FROM oven/bun:${BUN_VERSION} AS builder

WORKDIR /app

ARG UI=true
ENV UI=${UI}

COPY package.json bun.lock* ./
RUN bun install --frozen-lockfile

COPY . .

# Build Vue 3 / Vite Frontend
RUN bun run build:ui

# ── Production Stage ─────────────────────────────────────────
FROM oven/bun:${BUN_VERSION} AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV APP_PORT=3000

# Dependencies from builder stage (eliminates slow 2nd network download and cuts deployment time)
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/bun.lock ./bun.lock
COPY --from=builder /app/node_modules ./node_modules

# Backend source
COPY src ./src

# Frontend build output
COPY --from=builder /app/public ./public

# Config files & Startup Entrypoint
COPY drizzle.config.ts ./
COPY tsconfig.json ./
COPY docker-entrypoint.sh ./
RUN chmod +x docker-entrypoint.sh

EXPOSE 3000

HEALTHCHECK --interval=10s --timeout=5s --start-period=10s --retries=3 \
  CMD bun --eval "fetch(\`http://localhost:\${process.env.APP_PORT || process.env.PORT || 3000}/health\`).then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))"

CMD ["/bin/sh", "/app/docker-entrypoint.sh"]
