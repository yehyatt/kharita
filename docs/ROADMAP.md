# Roadmap and cost model

## v0.2 (done)

Hosted server at mapeleven.dev, marker icons and live vehicle markers, centre-pin picker support,
basemap places (tap and nearby), richer search with admin areas, the Explorer demo app, the website and docs.

## v0.3 (done): hosted service with free keys

Sign in with GitHub at mapeleven.dev/account, free API keys with optional domain restrictions, monthly
allowances (50,000 map loads and 50,000 searches per account), usage charts, keys in both SDKs.
Requests without a key keep working, with searches limited per IP.

## v0.4: the whole world

- World tiles and world search on a larger dedicated server.
- A CDN in front of the tiles, uptime monitoring.
- A hosted style editor (Maputnik) saving custom styles to your account.

## v0.5: routing and offline

- Offline regions: download a bounding box for use without a connection (MapLibre offline packs on Flutter, PMTiles file on web).
- Routing with [Valhalla](https://github.com/valhalla/valhalla) on the server: car, walking, cycling; route line drawing in the SDK.
- Isochrones ("everything within 10 minutes") and distance matrices, also from Valhalla.
- Native iOS (Swift) and Android (Kotlin) packages on the same server.

## Later

- Turn-by-turn navigation with [Ferrostar](https://github.com/stadiamaps/ferrostar) on top of Valhalla.
- Terrain and hillshade from Copernicus GLO-30 elevation data.
- React Native package.
- Per-country boundary and place-name "worldview" setting.

## Free, paid, and not possible

| Feature | Software | Running cost |
|---|---|---|
| Map display, styles, markers, GeoJSON, clustering | MapLibre (BSD) | Free |
| Public tiles for development | OpenFreeMap | Free (fair use) |
| Own tiles | Protomaps extract + go-pmtiles | Server storage and bandwidth |
| Search and reverse geocoding | Photon | Server RAM |
| Routing, isochrones, navigation | Valhalla, Ferrostar | Server RAM and CPU |
| Live traffic | None open | Paid data (TomTom, HERE) |
| High-resolution satellite imagery | None open (Sentinel-2 is 10 m); the SDK shows Esri, MapTiler or your own imagery (v0.3.1) | Paid imagery, on your own key |
| Rich business data (ratings, photos, hours) | OSM and Overture are thin | Paid data or your own |

Not possible: production apps on the public `tile.openstreetmap.org` or public Nominatim
(their usage policies forbid it), or removing OpenStreetMap attribution (ODbL).
