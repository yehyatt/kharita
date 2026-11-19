#!/usr/bin/env bash
# Schedule scripts/refresh.sh for 02:00 UTC on the 20th of each month (Overture
# publishes a release mid-month). flock stops two runs overlapping.
set -euo pipefail
dir="$(cd "$(dirname "$0")/.." && pwd)"
cat > /etc/cron.d/mapeleven-refresh <<CRON
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
0 2 20 * * root flock -n /run/mapeleven-refresh.lock ${dir}/scripts/refresh.sh >> /var/log/mapeleven-refresh.log 2>&1
CRON
chmod 644 /etc/cron.d/mapeleven-refresh
echo "Installed /etc/cron.d/mapeleven-refresh"
