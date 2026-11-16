#!/usr/bin/env bash
# Fonts (Noto Sans incl. Arabic ranges) and sprites from protomaps/basemaps-assets (OFL / CC0).
set -euo pipefail
cd "$(dirname "$0")/.."
rm -rf data/assets && mkdir -p data/assets
curl -fsSL https://github.com/protomaps/basemaps-assets/archive/refs/heads/main.tar.gz \
  | tar -xz -C data/assets --strip-components=1 basemaps-assets-main/fonts basemaps-assets-main/sprites
mkdir -p data/assets/rtl
curl -fsSL -o data/assets/rtl/mapbox-gl-rtl-text.js https://unpkg.com/@mapbox/mapbox-gl-rtl-text@0.3.0/dist/mapbox-gl-rtl-text.js
du -sh data/assets/*
