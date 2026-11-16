#!/usr/bin/env bash
# Cut a region out of the latest Protomaps daily planet build (range requests, no full download).
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source .env; set +a
mkdir -p data/tiles
BUILD=$(curl -fsSL https://build-metadata.protomaps.dev/builds.json | python3 -c 'import json,sys; print(json.load(sys.stdin)[-1]["key"])')
echo "Extracting ${REGION_NAME} (${REGION_BBOX}, z0-${MAX_ZOOM}) from ${BUILD}"
docker run --rm -v "$PWD/data/tiles:/out" protomaps/go-pmtiles:v1.30.3 \
  extract "https://build.protomaps.com/${BUILD}" "/out/${REGION_NAME}.pmtiles.tmp" \
  --bbox="${REGION_BBOX}" --maxzoom="${MAX_ZOOM}" --download-threads=8
mv "data/tiles/${REGION_NAME}.pmtiles.tmp" "data/tiles/${REGION_NAME}.pmtiles"
ls -lh "data/tiles/${REGION_NAME}.pmtiles"
