#!/usr/bin/env bash
# Generate light/dark/... x ar/en MapLibre styles pointing at this server.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source .env; set +a
# Include the Overture places layer once scripts/import-places.sh has built it.
OVERTURE_FLAG=""; [ -f data/tiles/overture.pmtiles ] && OVERTURE_FLAG="--overture"
docker run --rm -v "$PWD/../styles:/styles" -v "$PWD/data/styles:/out" -w /styles node:22-alpine \
  sh -c "npm ci --silent && node build.mjs --base-url=https://${DOMAIN} --tiles=${REGION_NAME} --out=/out ${OVERTURE_FLAG}"
ls data/styles
