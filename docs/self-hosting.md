---
title: Self-hosting
order: 6
---

# Self-hosting

The Mapeleven server is one Docker Compose stack: vector tiles, styles, fonts, icons and search behind Caddy with automatic HTTPS. It runs on a single small server; mapeleven.dev itself is a 4 vCPU, 8 GB ARM machine.

| Path | What | Software |
|---|---|---|
| `/tiles/{region}.json`, `/tiles/{region}/{z}/{x}/{y}.mvt` | Vector tiles | go-pmtiles over a Protomaps extract |
| `/styles/{theme}-{lang}.json` | MapLibre styles, 5 themes in Arabic and English | `styles/build.mjs` |
| `/assets/fonts`, `/assets/sprites`, `/assets/rtl` | Glyphs (Arabic included), icons, RTL plugin | Protomaps basemaps assets |
| `/search/api`, `/search/reverse` | Search and reverse geocoding | Photon |

## Requirements

- A Linux server with Docker (Ubuntu 24.04 tested), 4 vCPU, 8 GB RAM, 40 GB disk for Jordan and the GCC.
- A domain with an A record pointing at the server.
- Ports 80 and 443 open.

## Setup

```bash
git clone https://github.com/yehyatt/mapeleven && cd mapeleven/server
cp .env.example .env              # set DOMAIN, REGION_BBOX, PHOTON_REGIONS
./scripts/extract-tiles.sh        # cuts your region from the latest daily OpenStreetMap build
./scripts/fetch-assets.sh         # fonts, sprites, RTL plugin
./scripts/build-styles.sh         # styles that point at https://$DOMAIN
docker compose up -d              # Caddy + tiles

./scripts/import-search.sh        # search index for PHOTON_REGIONS, Arabic and English (needs zstd)
docker compose --profile search up -d

./scripts/import-places.sh        # optional: Overture places OpenStreetMap lacks (map + search)
```

`import-places.sh` adds shops, restaurants, clinics and other places from [Overture Maps](https://overturemaps.org) (Apache 2.0 and CDLA Permissive 2.0) that OpenStreetMap does not have yet, for the countries in `OVERTURE_COUNTRIES`. Places OSM already has, low-confidence or closed places, and nightlife, alcohol, gambling and adult categories are left out. They get their own map layer and join the search index; OSM data is not changed.

On Hetzner Cloud, `server/scripts/hetzner-create.sh` creates the server, firewall and SSH key, and `server/cloud-init.yaml` installs Docker and clones the repository on first boot.

Then point the SDK at it:

```dart
MapelevenMap(provider: MapelevenProvider.selfHosted('https://maps.example.com'))
```

```ts
new MapelevenMap("map", { provider: selfHosted("https://maps.example.com") });
```

## Choosing a region

`REGION_BBOX` is `minLon,minLat,maxLon,maxLat`. The default `34.0,12.0,60.5,33.5` covers Jordan and the Arabian Peninsula (about 1.4 GB of tiles). `PHOTON_REGIONS` lists Photon dump names from [download1.graphhopper.com/public/asia](https://download1.graphhopper.com/public/asia/), for example `jordan arabian-peninsula`; they are merged into one index (about a million places for the default).

A bigger region costs disk for tiles and RAM for search; raise `PHOTON_HEAP` above `2g` for countries with many millions of addresses.

## Extra domains

`REDIRECT_DOMAINS="example.com www.example.com"` in `.env` sends those hosts to `DOMAIN` with a permanent redirect; `www.DOMAIN` always redirects.

## Updating the data

OpenStreetMap changes every day. Re-run monthly (or weekly):

```bash
./scripts/extract-tiles.sh && docker compose restart tiles
./scripts/import-search.sh && docker compose --profile search up -d
./scripts/import-places.sh        # if you use Overture places
```

The scripts build the new data first and swap it in, so the server keeps answering during the update.

## Attribution

Keep "© OpenStreetMap contributors" visible wherever the map shows. The SDKs do this for you; if you draw tiles with other software, add it yourself.
