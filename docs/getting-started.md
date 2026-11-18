---
title: Getting started
description: Add open-source maps, place search and markers to a Flutter or web app in minutes with Mapeleven, on OpenStreetMap and MapLibre, with no API keys.
order: 1
---

# Getting started

Mapeleven gives Flutter and web apps a full map stack on open data: vector maps, Arabic and English labels, place search, reverse geocoding, markers with your own icons, zones and clusters. There are no per-request fees, and you can start without a key.

You choose where the map data comes from with a **provider**. Your map code stays the same when you switch.

| Provider | What it is | Use it for |
|---|---|---|
| `hosted(key: ...)` | The hosted service at `mapeleven.dev`, with your free key | Production apps: your own monthly allowance and usage charts |
| `hosted()` | The same service without a key; searches are limited per device | Trying things out and development |
| `selfHosted(url)` | Your own copy of the server, any region you choose | Production at scale, other regions, full control |
| `openFreeMap()` | Community tiles for the whole world, public Photon search | Prototypes outside the hosted region |

## Get a free key

1. Open [mapeleven.dev/account](https://mapeleven.dev/account/) and sign in with GitHub.
2. Copy the key that is waiting for you (it starts with `mel_`).
3. Pass it to the provider: `MapelevenProvider.hosted(key: 'mel_...')` in Flutter, `hosted({ key: "mel_..." })` on the web.

Each account gets 50,000 map loads and 50,000 searches a month for free; tiles for those map loads are not counted against you. The account page shows your usage per day and per key. Keys are public, like Mapbox public tokens: they end up inside your app. To stop other websites from using yours, list your domains on the key.

You can follow the steps below without a key first and add it later; nothing else changes.

## Flutter

### 1. Add the package

```yaml
dependencies:
  mapeleven:
    git:
      url: https://github.com/yehyatt/mapeleven
      path: packages/mapeleven_flutter
      ref: v0.3.1
```

The pub.dev release (`mapeleven: ^0.3.1`) follows; the API is the same.

### 2. Platform setup

- **iOS:** set the deployment target to 15.5 or later (`ios/Podfile` and the Runner target). If you show the user's location, add `NSLocationWhenInUseUsageDescription` to `Info.plist`.
- **Android:** `minSdkVersion 21` or later. For location, add `ACCESS_FINE_LOCATION` to `AndroidManifest.xml`.
- **Web:** nothing extra. MapLibre GL JS and the Arabic shaping plugin load automatically.

### 3. Show a map

```dart
import 'package:mapeleven/mapeleven.dart';

MapelevenMap(
  provider: MapelevenProvider.hosted(key: 'mel_...'), // your key from mapeleven.dev/account
  language: MapelevenLanguage.ar,
  initialCenter: const LatLng(31.9539, 35.9106), // Amman
  initialZoom: 13,
  onMapReady: (map) async {
    await map.addMarker(const LatLng(31.9539, 35.9106), label: 'عمّان');
  },
)
```

Change `language` or `theme` and rebuild: markers, icons and layers are put back automatically.

## Web

### 1. Install

```bash
npm install mapeleven maplibre-gl
```

### 2. Show a map

```html
<div id="map" style="height: 480px"></div>
```

```ts
import { MapelevenMap, hosted } from "mapeleven";
import "mapeleven/style.css";
// Vite: MapLibre 6 needs its worker URL when bundled.
import workerUrl from "maplibre-gl/dist/maplibre-gl-worker.mjs?url";

const map = new MapelevenMap("map", { provider: hosted({ key: "mel_..." }), language: "ar", zoom: 13, workerUrl });
map.addMarker([35.9106, 31.9539], { popup: "عمّان" });
```

With Vite, also add `optimizeDeps: { exclude: ["maplibre-gl"] }` to `vite.config.ts`.

Coordinates on the web follow MapLibre and GeoJSON order: `[longitude, latitude]`. In Flutter they are `LatLng(latitude, longitude)`.

## Starter repos

Clone one and run it, then change it into your app.

| Repo | What |
|---|---|
| [mapeleven-flutter-starter](https://github.com/yehyatt/mapeleven-flutter-starter) | The smallest useful Flutter app: map, search, Arabic / English |
| [mapeleven-delivery-template](https://github.com/yehyatt/mapeleven-delivery-template) | Flutter delivery flow: address picker, zones, live driver tracking |
| [mapeleven-web-starter](https://github.com/yehyatt/mapeleven-web-starter) | One HTML page with search and your own points, no build step |

## Next steps

- [Flutter guide](flutter.md): markers, icons, search, layers, places on the map.
- [Delivery recipes](delivery.md): address pin picker, delivery zones, live driver tracking.
- [Coming from Google Maps](google-maps.md): a step-by-step migration with a mapping table.
- [Self-hosting](self-hosting.md): run the server for your own region.

## Licences and attribution

The SDK is MIT licensed. Map data is © OpenStreetMap contributors under the ODbL, which requires visible attribution: Mapeleven keeps the attribution button on, so do not hide it or cover it with your own UI.
