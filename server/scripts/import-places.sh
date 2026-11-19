#!/usr/bin/env bash
# Add Overture Maps places (Apache 2.0 / CDLA Permissive 2.0) that OpenStreetMap
# lacks: download the region, drop what OSM already has, build the `overture`
# tile layer, then rebuild styles and search. Run after import-search.sh has
# fetched the Photon dumps; re-run monthly with the other refreshes.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source .env; set +a
mkdir -p data/places

echo "1/4 Downloading Overture places for ${REGION_BBOX}"
rm -f data/places/overture-places.geojsonseq*
docker run --rm -v "$PWD/data/places:/out" python:3.12-slim sh -c \
  "pip install -q overturemaps && overturemaps download --bbox=${REGION_BBOX} -f geojsonseq --type=place -o /out/overture-places.geojsonseq"

echo "2/4 Keeping places OSM does not have"
python3 scripts/places/overture.py data/places/overture-places.geojsonseq data/places data/photon/photon-dump-*-latest.jsonl.zst

echo "3/4 Building the overture tile layer"
docker build -q -t mapeleven-tippecanoe scripts/places >/dev/null
# tippecanoe picks the format from the extension, so build as .pmtiles outside
# the served directory, then move it in.
docker run --rm -v "$PWD/data/places:/in" mapeleven-tippecanoe -o /in/overture.pmtiles --force -l pois \
  -Z13 -z15 -r1 --no-tile-size-limit --no-feature-limit -q \
  --attribution='<a href="https://overturemaps.org">Overture Maps</a>' -n "Overture places" /in/overture-pois.geojsonseq
mv data/places/overture.pmtiles data/tiles/overture.pmtiles
docker compose restart tiles

echo "4/4 Styles and search"
scripts/build-styles.sh
scripts/import-search.sh
docker compose --profile search up -d
rm -f data/places/overture-places.geojsonseq
