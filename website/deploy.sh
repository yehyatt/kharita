#!/usr/bin/env bash
# Build the web SDK, the Explorer web app and the website, then upload them to the
# server's data/site directory (served by Caddy at the domain root).
# Usage: website/deploy.sh [ssh-host]    (default: mapeleven, from ~/.ssh/config)
# Set ESRI_KEY_FILE to a file holding an ArcGIS key to offer Satellite in the Explorer.
set -euo pipefail
host="${1:-mapeleven}"
root="$(cd "$(dirname "$0")/.." && pwd)"

(cd "$root/packages/mapeleven-web" && npm run build >/dev/null)
defines=()
if [ -n "${ESRI_KEY_FILE:-}" ]; then defines+=("--dart-define=ESRI_KEY=$(tr -d ' \n\r' < "$ESRI_KEY_FILE")"); fi
(cd "$root/apps/explorer" && flutter build web --release --base-href /explorer/ ${defines[@]+"${defines[@]}"} >/dev/null)
(cd "$root/website" && npm install --silent && node build.mjs)

# Older /sdk/web/<version>/ folders stay on the server: pages pin them.
rsync -az --delete --filter="P /sdk/web/**" "$root/website/dist/" "$host:/opt/mapeleven/server/data/site/"
echo "Deployed to $host"
