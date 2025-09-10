# ---- build stage ----
FROM node:22-bookworm-slim AS build
WORKDIR /work

# CI-friendly env
ENV HUSKY=0
ENV CI=true

# Use pnpm (lockfile v9 compatible)
RUN corepack enable && corepack prepare pnpm@9.15.9 --activate

# (Optional) public URL for client code; Coolify can pass it as a build-arg
ARG VITE_PUBLIC_APP_URL
ENV VITE_PUBLIC_APP_URL=${VITE_PUBLIC_APP_URL}

# Install deps efficiently
COPY package.json pnpm-lock.yaml* ./
RUN pnpm fetch

# Copy the rest and build
COPY . .
RUN pnpm install --offline --frozen-lockfile
RUN NODE_OPTIONS=--max-old-space-size=4096 pnpm run build

# Keep only prod deps for runtime
RUN pnpm prune --prod --ignore-scripts


# ---- runtime stage ----
FROM node:22-bookworm-slim AS runtime

# Put the runtime app somewhere that will NOT be shadowed by any host mounts
# Coolify tends to use /app in examples; avoid that path.
WORKDIR /srv/app

ENV NODE_ENV=production
ENV PORT=3000
ENV HOST=0.0.0.0

# Install curl so Coolify's healthcheck works
RUN apt-get update && apt-get install -y --no-install-recommends curl \
  && rm -rf /var/lib/apt/lists/*

# Copy only what we need to run
COPY --from=build /work/build /srv/app/build
COPY --from=build /work/node_modules /srv/app/node_modules
COPY --from=build /work/package.json /srv/app/package.json

# (Optional) drop privileges
# RUN useradd -r -u 10001 -g root appuser && chown -R appuser:root /srv/app
# USER appuser

EXPOSE 3000

# Healthcheck for Coolify
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=5 \
  CMD curl -fsS http://localhost:3000/ || exit 1

# Start the Remix server (note the new path under /srv/app)
CMD ["node", "/srv/app/build/server/index.js"]
