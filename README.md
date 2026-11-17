# Mapeleven

**Website and docs: [mapeleven.dev](https://mapeleven.dev) · Demo app: [mapeleven.dev/explorer](https://mapeleven.dev/explorer/)**

Open maps made simple for **Flutter** and the **web**. Mapeleven wraps
[MapLibre](https://maplibre.org) and [OpenStreetMap](https://www.openstreetmap.org) data
in one small API with Arabic-first styles, place search, and a self-hostable server
that runs on a single Hetzner box.

- **No API keys, no per-request fees.** Start on free public tiles, then move to your own server with one line.
- **Arabic first.** Labels in Arabic or English, switchable at runtime; RTL shaping handled for you.
- **Same model everywhere.** Providers, themes, markers, GeoJSON layers and search look the same in Dart and TypeScript.
- **Licence-safe by default.** OpenStreetMap attribution stays on; public services are used only within their fair-use terms.

| Package | Platforms | Path |
|---|---|---|
| `mapeleven` (pub.dev) | Android, iOS, Flutter web | `packages/mapeleven_flutter` |
| `mapeleven` (npm) | Any web app | `packages/mapeleven-web` |
| Map server | Docker on any VPS | `server/` |
| Explorer demo app | Android, iOS, web | `apps/explorer` |
| Website and docs | Static site | `website/`, `docs/` |

## Quick start: web

```bash
npm install mapeleven maplibre-gl
```

```ts
import { MapelevenMap, openFreeMap } from "mapeleven";
import "mapeleven/style.css";
// Vite: MapLibre 6 needs its worker URL when bundled.
import workerUrl from "maplibre-gl/dist/maplibre-gl-worker.mjs?url";

const map = new MapelevenMap("map", { provider: openFreeMap(), language: "ar", workerUrl });

map.addMarker([35.9106, 31.9539], { popup: "عمّان" });
map.addGeoJSON("branches", branchesGeoJson, { cluster: true, onClick: (f) => console.log(f.properties) });

const places = await map.search.search("الجامعة الأردنية", { language: "ar" });
map.flyTo([places[0].lng, places[0].lat]);

await map.setLanguage("en"); // layers and markers are kept
await map.setTheme("dark");
```

With Vite, also add `optimizeDeps: { exclude: ["maplibre-gl"] }` to `vite.config.ts`.

## Quick start: Flutter

```yaml
dependencies:
  mapeleven:
    git: { url: https://github.com/yehyatt/mapeleven, path: packages/mapeleven_flutter, ref: v0.2.0 }
```

```dart
MapelevenMap(
  provider: MapelevenProvider.openFreeMap(),
  language: MapelevenLanguage.ar,
  theme: MapelevenTheme.light,
  onMapReady: (map) async {
    await map.addMarker(const LatLng(31.9539, 35.9106), label: 'عمّان');
    await map.addGeoJson('branches', branchesGeoJson,
        options: const MapelevenGeoJsonOptions(cluster: true));
    final places = await map.search.search('الجامعة الأردنية', language: MapelevenLanguage.ar);
    await map.flyTo(places.first.position);
  },
)
```

Change `language` or `theme` and rebuild; markers and layers are re-added automatically.
To show the user's location, request location permission in your app and pass `showUserLocation: true`.

## Providers

| Provider | Tiles | Search | Use for |
|---|---|---|---|
| `hosted()` | mapeleven.dev: Jordan and the GCC | About a million places, Arabic and English | Apps in the region, demos, pilots |
| `openFreeMap()` | [OpenFreeMap](https://openfreemap.org) public tiles | [Photon](https://photon.komoot.io) public demo | Development, prototypes, small apps |
| `selfHosted(url)` | Your server (Protomaps extract) | Your Photon index | Production |

Moving to production is one line: `selfHosted("https://maps.example.com")`. See [server/README.md](server/README.md).

## Examples

```bash
cd examples/web && npm install && npm run dev                 # http://localhost:5173
cd examples/flutter && flutter run                            # phone, emulator or -d chrome
flutter run --dart-define=MAPELEVEN_SERVER=https://maps.example.com   # against your server
```

## Starter repos

| Repo | What |
|---|---|
| [mapeleven-flutter-starter](https://github.com/yehyatt/mapeleven-flutter-starter) | The smallest useful Flutter app: map, search, Arabic / English |
| [mapeleven-delivery-template](https://github.com/yehyatt/mapeleven-delivery-template) | Flutter delivery flow: address picker, zones, live driver tracking |
| [mapeleven-web-starter](https://github.com/yehyatt/mapeleven-web-starter) | One HTML page with search and your own points, no build step |

## Guides

[Getting started](docs/getting-started.md) · [Flutter](docs/flutter.md) · [Web](docs/web.md) ·
[Delivery recipes](docs/delivery.md) · [Coming from Google Maps](docs/google-maps.md) · [Self-hosting](docs/self-hosting.md)

## What is in v0.2

| Feature | Web | Flutter |
|---|---|---|
| Vector map, pan/zoom/rotate | ✅ | ✅ |
| Arabic / English labels, runtime switch | ✅ | ✅ |
| Light / dark themes (5 on self-hosted) | ✅ | ✅ |
| Markers with labels or popups | ✅ | ✅ |
| Custom marker icons, rotation, live moving markers | | ✅ |
| Centre-pin picker (`onCameraIdle`), `fitPoints` | map events | ✅ |
| Tap and list basemap places (pharmacies, mosques, fuel...) | | ✅ |
| Search filters (category, box), admin areas for zone matching | ✅ | ✅ |
| GeoJSON points, lines, polygons, clustering, tap handlers | ✅ | ✅ |
| User location | ✅ | ✅ (app requests permission) |
| Place search, reverse geocoding | ✅ | ✅ |
| Self-hostable server (tiles, styles, fonts, search) | ✅ | ✅ |

See [docs/ROADMAP.md](docs/ROADMAP.md) for what comes next and what costs money.

## Licences

Code: MIT. Map data © [OpenStreetMap contributors](https://www.openstreetmap.org/copyright), ODbL;
the attribution control must stay visible. Basemap schema and styles by
[Protomaps](https://protomaps.com) (BSD), fonts Noto (OFL).
