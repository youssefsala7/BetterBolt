# ---- build stage ----
FROM node:22-bookworm-slim AS build
WORKDIR /app

# Disable husky hooks in CI/builds
ENV HUSKY=0
ENV CI=true

# Use pnpm
RUN corepack enable && corepack prepare pnpm@9.14.4 --activate

# Install deps efficiently
COPY package.json pnpm-lock.yaml* ./
RUN pnpm fetch

# Copy source and build
COPY . .
# Install WITH devDependencies (no NODE_ENV=production here)
RUN pnpm install --offline --frozen-lockfile
# Build the Remix app
RUN NODE_OPTIONS=--max-old-space-size=4096 pnpm run build
# After building, keep only prod deps for runtime
RUN pnpm prune --prod

# ---- runtime stage ----
FROM node:22-bookworm-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3000
ENV HOST=0.0.0.0
EXPOSE 3000

# Copy only what we need to run
COPY --from=build /app/build /app/build
COPY --from=build /app/node_modules /app/node_modules
COPY --from=build /app/package.json /app/package.json

# Run the server – no wrangler in production
CMD ["node", "build/server/index.js"]
