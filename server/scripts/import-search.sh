#!/usr/bin/env bash
# Download Photon and import the regional dumps (Arabic + English names). Re-run weekly to refresh.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source .env; set +a
mkdir -p data/photon && cd data/photon
curl -fsSL -o photon.jar "https://github.com/komoot/photon/releases/download/${PHOTON_VERSION}/photon-${PHOTON_VERSION}.jar"
rm -rf photon_data
for region in ${PHOTON_REGIONS}; do
  file="photon-dump-${region}-1.0-latest.jsonl.zst"
  curl -fsSL -o "$file" "https://download1.graphhopper.com/public/asia/${region}/${file}"
done
docker run --rm -v "$PWD:/photon" -w /photon eclipse-temurin:21-jre \
  sh -c 'for f in photon-dump-*.jsonl.zst; do java -Xmx${PHOTON_HEAP:-2g} -jar photon.jar import -import-file "$f" -languages ar,en -data-dir /photon || exit 1; done'
echo "Imported. Start with: docker compose --profile search up -d"
