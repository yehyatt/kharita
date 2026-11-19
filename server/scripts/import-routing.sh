#!/usr/bin/env bash
# Build the Valhalla road graph from Geofabrik's OpenStreetMap extracts, then
# swap it in, so a running routing service keeps answering until the new graph
# is ready. Re-run monthly (scripts/refresh.sh does).
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source .env; set +a
: "${ROUTING_PBFS:=asia/jordan asia/gcc-states asia/yemen}"
rm -rf data/valhalla-next && mkdir -p data/valhalla-next
urls=""
for region in ${ROUTING_PBFS}; do urls="$urls https://download.geofabrik.de/${region}-latest.osm.pbf"; done
echo "Building the road graph from:${urls}"
# The image runs as uid 59999 and writes its config and tiles into /custom_files.
chown 59999:59999 data/valhalla-next
docker run --rm -v "$PWD/data/valhalla-next:/custom_files" \
  -e tile_urls="${urls# }" -e serve_tiles=False -e build_elevation=False \
  -e build_admins=True -e build_time_zones=True -e force_rebuild=True \
  ghcr.io/valhalla/valhalla-scripted:3.6.1
ls data/valhalla-next/valhalla_tiles.tar >/dev/null
# The extracts are only needed for the build.
rm -f data/valhalla-next/*.pbf
docker compose --profile routing stop routing 2>/dev/null || true
rm -rf data/valhalla
mv data/valhalla-next data/valhalla
docker compose --profile routing up -d routing
echo "Routing graph ready: $(du -sh data/valhalla | cut -f1)"
