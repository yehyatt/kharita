---
title: Coming from Mapbox
order: 4.5
description: Move a Flutter or web app from Mapbox to Mapeleven, an open-source Mapbox alternative on MapLibre and OpenStreetMap with no access tokens and no per-load billing.
---

# Coming from Mapbox

Mapeleven runs on [MapLibre](https://maplibre.org), the open-source continuation of Mapbox GL. When Mapbox moved Mapbox GL JS v2 to a proprietary licence in December 2020, the community forked the last open release (v1.13) as MapLibre GL JS. So on the web most of your map code carries over, and in Flutter the concepts are the same.

What you gain: a free key in a minute with no card, no per-map-load or per-user billing, OpenStreetMap data you can host yourself, and labels in Arabic or English with correct right-to-left shaping. What you give up today: Mapbox's own styles (`mapbox://` URLs and Mapbox Standard), Mapbox satellite imagery, live traffic, and the Directions API (road routing is on the [roadmap](https://github.com/yehyatt/mapeleven/blob/main/docs/ROADMAP.md)).

## Web: Mapbox GL JS

Before:

```js
import mapboxgl from "mapbox-gl";

mapboxgl.accessToken = "pk.…";
const map = new mapboxgl.Map({
  container: "map",
  style: "mapbox://styles/mapbox/streets-v12",
  center: [35.91, 31.95],
  zoom: 12,
});
new mapboxgl.Marker().setLngLat([35.91, 31.95]).addTo(map);
```

After:

```js
import { MapelevenMap, hosted } from "mapeleven";

const map = new MapelevenMap("map", { provider: hosted({ key: "mel_..." }), center: [35.91, 31.95], zoom: 12 });
map.addMarker([35.91, 31.95]);
```

With a bundler such as Vite, also pass `workerUrl` and import `mapeleven/style.css`, as the [Web guide](web.md) shows.

`map.map` is a full `maplibregl.Map`, so code that talks to the map directly keeps working after replacing `mapboxgl` with `maplibregl`: `addSource`, `addLayer`, `setPaintProperty`, `on("click", layerId, …)`, `queryRenderedFeatures`, popups and custom markers. Style expressions are compatible for everyday use.

| Mapbox GL JS | Mapeleven web |
|---|---|
| `mapboxgl.accessToken = …` | `hosted({ key: "mel_…" })`: a free key from [your account](https://mapeleven.dev/account/), optional while developing |
| `style: "mapbox://styles/…"` | `theme: "light"` (also `dark`, `white`, `grayscale`, `black`) |
| `new mapboxgl.Map({...})` | `new MapelevenMap(el, {...})`; the MapLibre map is `map.map` |
| `new mapboxgl.Marker().setLngLat(p).addTo(map)` | `map.addMarker(p, { color, popup })` |
| `map.addSource` + `map.addLayer` for GeoJSON | `map.addGeoJSON(name, data, { cluster, color })`, or the same MapLibre calls on `map.map` |
| `map.flyTo({ center, zoom })` | `map.flyTo(center, zoom)` |
| `map.fitBounds(bounds)` | `map.fitBounds([w, s, e, n])` |
| `GeolocateControl` | On by default (`controls: { locate: true }`) |
| `mapbox-gl-rtl-text` plugin | Loaded for you |
| Mapbox Geocoding / Search Box API | `map.search.search(text, { near })` and `map.search.reverse(lat, lng)` |

Full details: [Web guide](web.md).

## Flutter: mapbox_maps_flutter

| mapbox_maps_flutter | Mapeleven |
|---|---|
| `MapboxOptions.setAccessToken(…)` | `MapelevenProvider.hosted(key: 'mel_…')` |
| `MapWidget(cameraOptions: CameraOptions(center: Point(coordinates: Position(lng, lat)), zoom: z))` | `MapelevenMap(provider: MapelevenProvider.hosted(), initialCenter: LatLng(lat, lng), initialZoom: z)` |
| `onMapCreated: (MapboxMap map) {}` | `onMapReady: (MapelevenController map) {}` |
| `styleUri: MapboxStyles.MAPBOX_STREETS` | `theme: MapelevenTheme.light` |
| `map.flyTo(CameraOptions(...), MapAnimationOptions(...))` | `map.flyTo(LatLng(lat, lng), zoom: z)` |
| `map.annotations.createPointAnnotationManager()` then `manager.create(PointAnnotationOptions(...))` | `map.addMarker(LatLng(lat, lng), id: 'shop', icon: 'shop')` |
| Marker image bytes | `map.registerIcon(MapelevenIcon('shop', pngBytes))`, or `MapelevenIcon.fromIconData` from a Material icon |
| GeoJSON source and layers | `map.addGeoJson(name, data, MapelevenGeoJsonOptions(cluster: true))` |
| Camera change listeners | `onCameraIdle: (center, zoom) {}` |

Note the coordinate order: Mapbox's `Position` is longitude first, Mapeleven's `LatLng` is latitude first.

Full details: [Flutter guide](flutter.md).

## Search and geocoding

Mapbox's Geocoding and Search Box APIs become Mapeleven search, served by [Photon](https://github.com/komoot/photon) on the same server as the tiles. Results carry street, district, city, county and governorate in Arabic or English. Use `near` to rank results around the user and `osmTags` to filter by kind (for example `amenity:pharmacy`). For backend code that calls a geocoding API over HTTP, the [Google Maps guide](google-maps.md#2-backend-geocoding-and-place-search) has a drop-in TypeScript provider that works the same way for Mapbox users.

## Rolling out

1. Add Mapeleven next to Mapbox behind a flag, on one screen first.
2. Compare search and reverse geocoding results for your real addresses, and fix any naming differences in your own lookup tables.
3. Switch the flag for everyone, keep Mapbox for one release as a fallback, then remove the Mapbox token from your builds and rotate it.
