#!/usr/bin/env bash
# Build the web SDK, the Explorer web app and the website, then upload them to the
# server's data/site directory (served by Caddy at the domain root).
# Usage: website/deploy.sh [ssh-host]    (default: mapeleven, from ~/.ssh/config)
set -euo pipefail
host="${1:-mapeleven}"
root="$(cd "$(dirname "$0")/.." && pwd)"

(cd "$root/packages/mapeleven-web" && npm run build >/dev/null)
(cd "$root/apps/explorer" && flutter build web --release --base-href /explorer/ >/dev/null)
(cd "$root/website" && npm install --silent && node build.mjs)

# Older /sdk/web/<version>/ folders stay on the server: pages pin them.
rsync -az --delete --filter="P /sdk/web/**" "$root/website/dist/" "$host:/opt/mapeleven/server/data/site/"
echo "Deployed to $host"
