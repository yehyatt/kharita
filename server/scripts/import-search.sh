#!/usr/bin/env bash
# Download Photon and the regional dumps, merge them, and build one search index
# (Arabic + English names). Re-run weekly to refresh; needs zstd on the host.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source .env; set +a
command -v zstd >/dev/null || { echo "zstd is required (apt-get install zstd)"; exit 1; }
mkdir -p data/photon && cd data/photon
curl -fsSL -o photon.jar "https://github.com/komoot/photon/releases/download/${PHOTON_VERSION}/photon-${PHOTON_VERSION}.jar"

# Photon imports a single dump, so the regions are merged into one stream: the
# first dump whole, the others without their first two lines (file header and
# CountryInfo, identical in every dump). The dumps are zstd-compressed JSONL.
rm -f merged.jsonl
first=1
for region in ${PHOTON_REGIONS}; do
  file="photon-dump-${region}-1.0-latest.jsonl.zst"
  curl -fsSL -o "$file" "https://download1.graphhopper.com/public/asia/${region}/${file}"
  if [ "$first" = 1 ]; then zstd -dc "$file" >> merged.jsonl; first=0
  else zstd -dc "$file" | tail -n +3 >> merged.jsonl; fi
done
# Overture places that OSM lacks (scripts/import-places.sh), if built.
if [ -f ../places/overture-photon.jsonl ]; then
  cat ../places/overture-photon.jsonl >> merged.jsonl
  echo "Added $(wc -l < ../places/overture-photon.jsonl) Overture places"
fi
echo "Merged $(grep -c '"type":"Place"' merged.jsonl) places from: ${PHOTON_REGIONS}"

# Build into a separate directory, then swap it in, so a running server keeps
# answering until the new index is ready.
rm -rf next && mkdir next
docker run --rm -v "$PWD:/photon" -w /photon eclipse-temurin:21-jre \
  java "-Xmx${PHOTON_HEAP:-2g}" -jar photon.jar import -import-file merged.jsonl -languages ar,en -j 2 -data-dir /photon/next
rm -f merged.jsonl
cd ../..
docker compose --profile search stop search 2>/dev/null || true
rm -rf data/photon/photon_data
mv data/photon/next/photon_data data/photon/photon_data
rmdir data/photon/next
echo "Imported. Start with: docker compose --profile search up -d"
