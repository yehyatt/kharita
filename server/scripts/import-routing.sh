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
echo "Downloading and merging:${urls}"
# Neighbouring extracts overlap at the borders; Valhalla needs one file without
# duplicates, so osmium merges them first.
docker run --rm -v "$PWD/data/valhalla-next:/data" -w /data debian:bookworm-slim sh -c \
  "apt-get update -qq && apt-get install -y -qq osmium-tool curl ca-certificates >/dev/null \
   && for u in ${urls}; do curl -fsSL -O \$u; done \
   && osmium merge -o region.osm.pbf *-latest.osm.pbf && rm *-latest.osm.pbf"
# The image runs as uid 59999 and writes its config and tiles into /custom_files.
chown -R 59999:59999 data/valhalla-next
echo "Building the road graph"
docker run --rm -v "$PWD/data/valhalla-next:/custom_files" \
  -e serve_tiles=False -e build_elevation=False \
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
