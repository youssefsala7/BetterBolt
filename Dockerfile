# ---- build stage ----
FROM node:22-bookworm-slim AS build
ENV NODE_ENV=production
WORKDIR /app

# use pnpm
RUN corepack enable && corepack prepare pnpm@9.14.4 --activate

# install deps (efficiently)
COPY package.json pnpm-lock.yaml* ./
RUN pnpm fetch

# copy source and build
COPY . .
RUN pnpm install --offline --frozen-lockfile \
 && NODE_OPTIONS=--max-old-space-size=4096 pnpm run build

# ---- runtime stage ----
FROM node:22-bookworm-slim AS runtime
ENV NODE_ENV=production
WORKDIR /app

# copy only what we need to run
COPY --from=build /app/build /app/build
COPY --from=build /app/node_modules /app/node_modules
COPY --from=build /app/package.json /app/package.json

# the Remix server listens on 3000
ENV PORT=3000
ENV HOST=0.0.0.0
EXPOSE 3000

# run the server – no wrangler in production
CMD ["node", "build/server/index.js"]
