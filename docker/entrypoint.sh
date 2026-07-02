#!/bin/bash
# Ignite entrypoint — adapts Ignis's: download+extract Obsidian at first run, install the
# obsidian-headless CLI (runtime, for legal reasons), then exec the RUST ignite-server binary.
set -e

PUID=${PUID:-1000}
PGID=${PGID:-1000}

if ! getent group "$PGID" >/dev/null 2>&1; then
  groupadd -g "$PGID" ignite
fi
if ! id -u "$PUID" >/dev/null 2>&1; then
  GROUP_NAME=$(getent group "$PGID" | cut -d: -f1)
  useradd -u "$PUID" -g "$PGID" -m -s /bin/bash ignite 2>/dev/null || useradd -u "$PUID" -g "$GROUP_NAME" -M -N ignite
  RUN_USER="ignite"
else
  RUN_USER=$(id -un "$PUID")
fi

mkdir -p /app/data
chown -R "$PUID:$PGID" /vaults /app/obsidian-app /app/data 2>/dev/null || true

OBSIDIAN_DIR="${OBSIDIAN_ASSETS_PATH:-/app/obsidian-app}"
OBSIDIAN_VERSION="${OBSIDIAN_VERSION:-1.12.7}"

if [ ! -f "$OBSIDIAN_DIR/index.html" ]; then
  mkdir -p "$OBSIDIAN_DIR"
  if [ -n "$OBSIDIAN_PACKAGE" ] && [ -f "$OBSIDIAN_PACKAGE" ]; then
    echo "[ignite] Unpacking local Obsidian package: $OBSIDIAN_PACKAGE"
    cp "$OBSIDIAN_PACKAGE" /tmp/obsidian.asar.gz
    gunzip -f /tmp/obsidian.asar.gz
    npx --yes @electron/asar extract /tmp/obsidian.asar "$OBSIDIAN_DIR"
    rm -f /tmp/obsidian.asar
  else
    echo "[ignite] First run. Downloading Obsidian v${OBSIDIAN_VERSION}..."
    curl -fSL "https://github.com/obsidianmd/obsidian-releases/releases/download/v${OBSIDIAN_VERSION}/obsidian-${OBSIDIAN_VERSION}.asar.gz" \
      -o /tmp/obsidian.asar.gz
    gunzip /tmp/obsidian.asar.gz
    npx --yes @electron/asar extract /tmp/obsidian.asar "$OBSIDIAN_DIR"
    rm -f /tmp/obsidian.asar
  fi
  if [ ! -f "$OBSIDIAN_DIR/index.html" ]; then
    echo "[ignite] ERROR: setup did not produce $OBSIDIAN_DIR/index.html"
    exit 1
  fi
  echo "[ignite] Obsidian ready (v${OBSIDIAN_VERSION})."
else
  echo "[ignite] Obsidian already set up."
fi

# obsidian-headless (ob CLI) — installed at runtime for headless-sync (not bundled, legal).
if ! command -v ob &>/dev/null; then
  echo "[ignite] Installing obsidian-headless..."
  npm install -g --prefix /usr/local obsidian-headless --silent 2>/dev/null \
    && echo "[ignite] obsidian-headless $(ob --version 2>/dev/null) installed." \
    || echo "[ignite] WARNING: obsidian-headless not installed; headless sync unavailable."
fi

echo "[ignite] Starting ignite-server on :${PORT:-8080} (vaults=$VAULT_ROOT)"
exec gosu "$RUN_USER" /usr/local/bin/ignite-server
