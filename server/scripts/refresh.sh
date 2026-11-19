#!/usr/bin/env bash
# Monthly data refresh: fresh OpenStreetMap map tiles, then Overture places,
# styles and the search index (import-places.sh runs import-search.sh, which
# downloads fresh OSM search dumps). Installed by scripts/install-refresh.sh;
# safe to run by hand. Logs to /var/log/mapeleven-refresh.log when run by cron.
set -euo pipefail
cd "$(dirname "$0")/.."
echo "== Refresh started $(date -u '+%F %T') UTC"
git pull -q --ff-only || echo "git pull skipped (local changes or offline)"
scripts/extract-tiles.sh
docker compose restart tiles
scripts/import-places.sh
docker image prune -f >/dev/null
echo "== Refresh finished $(date -u '+%F %T') UTC"
