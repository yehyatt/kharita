# Kharita (خريطة)

Open maps made simple for **Flutter** and the **web**. Kharita wraps
[MapLibre](https://maplibre.org) and [OpenStreetMap](https://www.openstreetmap.org) data
in one small API with Arabic-first styles, place search, and a self-hostable server
that runs on a single Hetzner box.

- **No API keys, no per-request fees.** Start on free public tiles, then move to your own server with one line.
- **Arabic first.** Labels in Arabic or English, switchable at runtime; RTL shaping handled for you.
- **Same model everywhere.** Providers, themes, markers, GeoJSON layers and search look the same in Dart and TypeScript.
- **Licence-safe by default.** OpenStreetMap attribution stays on; public services are used only within their fair-use terms.

| Package | Platforms | Path |
|---|---|---|
| `kharita` (pub.dev) | Android, iOS, Flutter web | `packages/kharita_flutter` |
| `kharita` (npm) | Any web app | `packages/kharita-web` |
| Map server | Docker on any VPS | `server/` |

## Quick start: web

```bash
npm install kharita maplibre-gl
```

```ts
import { KharitaMap, openFreeMap } from "kharita";
import "kharita/style.css";
// Vite: MapLibre 6 needs its worker URL when bundled.
import workerUrl from "maplibre-gl/dist/maplibre-gl-worker.mjs?url";

const map = new KharitaMap("map", { provider: openFreeMap(), language: "ar", workerUrl });

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
  kharita: ^0.1.0
```

```dart
KharitaMap(
  provider: KharitaProvider.openFreeMap(),
  language: KharitaLanguage.ar,
  theme: KharitaTheme.light,
  onMapReady: (map) async {
    await map.addMarker(const LatLng(31.9539, 35.9106), label: 'عمّان');
    await map.addGeoJson('branches', branchesGeoJson,
        options: const KharitaGeoJsonOptions(cluster: true));
    final places = await map.search.search('الجامعة الأردنية', language: KharitaLanguage.ar);
    await map.flyTo(places.first.position);
  },
)
```

Change `language` or `theme` and rebuild; markers and layers are re-added automatically.
To show the user's location, request location permission in your app and pass `showUserLocation: true`.

## Providers

| Provider | Tiles | Search | Use for |
|---|---|---|---|
| `openFreeMap()` | [OpenFreeMap](https://openfreemap.org) public tiles | [Photon](https://photon.komoot.io) public demo | Development, prototypes, small apps |
| `selfHosted(url)` | Your server (Protomaps extract) | Your Photon index | Production |

Moving to production is one line: `selfHosted("https://maps.example.com")`. See [server/README.md](server/README.md).

## Examples

```bash
cd examples/web && npm install && npm run dev                 # http://localhost:5173
cd examples/flutter && flutter run                            # phone, emulator or -d chrome
flutter run --dart-define=KHARITA_SERVER=https://maps.example.com   # against your server
```

## What is in v0.1

| Feature | Web | Flutter |
|---|---|---|
| Vector map, pan/zoom/rotate | ✅ | ✅ |
| Arabic / English labels, runtime switch | ✅ | ✅ |
| Light / dark themes (5 on self-hosted) | ✅ | ✅ |
| Markers with labels or popups | ✅ | ✅ |
| GeoJSON points, lines, polygons, clustering, tap handlers | ✅ | ✅ |
| User location | ✅ | ✅ (app requests permission) |
| Place search, reverse geocoding | ✅ | ✅ |
| Self-hostable server (tiles, styles, fonts, search) | ✅ | ✅ |

See [docs/ROADMAP.md](docs/ROADMAP.md) for what comes next and what costs money.

## Licences

Code: MIT. Map data © [OpenStreetMap contributors](https://www.openstreetmap.org/copyright), ODbL;
the attribution control must stay visible. Basemap schema and styles by
[Protomaps](https://protomaps.com) (BSD), fonts Noto (OFL).
