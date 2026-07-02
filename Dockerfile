# Ignite — Docker image (dDeploymentDirection: Docker-only, reuse Ignis's built browser JS).
# Multi-stage: (1) build the Rust server; (2) clone+build Ignis's browser JS at the pinned ref;
# (3) a node runtime that downloads Obsidian at first run (adapting Ignis's entrypoint) and execs
# the ignite-server binary.
#
# NOTE: the full end-to-end (a browser loading Obsidian against this image) is a HUMAN demo
# verification (sprint15 DoD) — the AI verified the image builds + the server smoke-responds.

# ---- stage 1: Rust server ----
FROM rust:1 AS rustbuild
WORKDIR /build
COPY server/ ./server/
RUN cargo build --release --manifest-path server/Cargo.toml \
    && cp server/target/release/ignite-server /ignite-server

# ---- stage 2: Ignis browser JS (pinned ref) ----
FROM node:22 AS jsbuild
ARG IGNIS_REF=c9656b8a8dc7d8c69feccc632972948175e77429
RUN git clone https://github.com/Nystik-gh/ignis.git /ignis \
    && cd /ignis && git checkout "$IGNIS_REF" \
    && npm ci && node build.js
# Result: /ignis/packages/ui/dist, /ignis/packages/shim/dist,
# /ignis/apps/ignis-server/server/assets (the index.html template + overrides.css),
# /ignis/images/favicon.png, and the headless-sync bundled-plugin dist.

# ---- stage 3: runtime ----
FROM node:22-slim AS runtime
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl gosu ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=rustbuild /ignite-server /usr/local/bin/ignite-server
# Ignis's built browser JS + template assets (reused per dDeploymentDirection)
COPY --from=jsbuild /ignis/packages/ui/dist        /app/ui-dist
COPY --from=jsbuild /ignis/packages/shim/dist       /app/shim-dist
COPY --from=jsbuild /ignis/apps/ignis-server/server/assets /app/assets
COPY --from=jsbuild /ignis/images                   /app/images
COPY docker/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

ENV VAULT_ROOT=/vaults \
    DATA_ROOT=/app/data \
    OBSIDIAN_ASSETS_PATH=/app/obsidian-app \
    IGNITE_UI_DIST=/app/ui-dist \
    IGNITE_SHIM_DIST=/app/shim-dist \
    IGNITE_ASSETS_DIR=/app/assets \
    OBSIDIAN_VERSION=1.12.7 \
    PORT=8080
VOLUME ["/vaults"]
EXPOSE 8080
ENTRYPOINT ["/app/entrypoint.sh"]
