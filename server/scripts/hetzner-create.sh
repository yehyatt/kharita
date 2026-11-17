#!/usr/bin/env bash
# Create a Hetzner Cloud server ready for the Mapeleven stack.
# Needs: hcloud CLI, HCLOUD_TOKEN for the target project, an SSH public key.
# Usage: HCLOUD_TOKEN=... ./scripts/hetzner-create.sh <name> <ssh-pubkey-file> [type] [location]
set -euo pipefail
cd "$(dirname "$0")/.."
NAME=${1:?server name}; PUBKEY=${2:?ssh public key file}
TYPE=${3:-cax21}; LOCATION=${4:-fsn1}

hcloud ssh-key describe "$NAME" >/dev/null 2>&1 || hcloud ssh-key create --name "$NAME" --public-key-from-file "$PUBKEY"
if ! hcloud firewall describe "$NAME-fw" >/dev/null 2>&1; then
  hcloud firewall create --name "$NAME-fw"
  for rule in "tcp 22" "tcp 80" "tcp 443" "udp 443"; do
    set -- $rule
    hcloud firewall add-rule "$NAME-fw" --direction in --protocol "$1" --port "$2" --source-ips 0.0.0.0/0 --source-ips ::/0
  done
fi
hcloud server create --name "$NAME" --type "$TYPE" --location "$LOCATION" --image ubuntu-24.04 \
  --ssh-key "$NAME" --firewall "$NAME-fw" --user-data-from-file cloud-init.yaml
hcloud server enable-backup "$NAME"
hcloud server ip "$NAME"
