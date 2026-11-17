---
title: Web guide
order: 5
---

# Web guide

The `mapeleven` npm package wraps [MapLibre GL JS](https://maplibre.org) 6 with the same model as the Flutter package. Coordinates are `[longitude, latitude]`.

## Map

```ts
import { MapelevenMap, hosted } from "mapeleven";
import "mapeleven/style.css";
import workerUrl from "maplibre-gl/dist/maplibre-gl-worker.mjs?url"; // Vite

const map = new MapelevenMap("map", {
  provider: hosted({ key: "mel_..." }), // free key: mapeleven.dev/account
  language: "ar",            // optional: defaults to the page language
  theme: "light",            // light, dark, white, grayscale, black
  center: [35.9106, 31.9539],
  zoom: 13,
  controls: { navigation: true, locate: true, scale: false, fullscreen: false },
  workerUrl,
});

await map.ready;             // first style loaded
await map.setLanguage("en"); // markers and layers are kept
await map.setTheme("dark");
map.flyTo([35.91, 31.95], 16);
map.fitBounds([35.8, 31.9, 36.0, 32.05]);
map.locate();                // asks the browser for the user's position
```

`map.map` is the underlying `maplibregl.Map` for events and anything not wrapped, for example `map.map.on("moveend", ...)`.

## Markers and layers

```ts
map.addMarker([35.91, 31.95], { color: "#0F766E", popup: "Branch 12", draggable: false });

const stores = map.addGeoJSON("stores", featureCollection, {
  cluster: true,
  color: "#0F766E",
  onClick: (feature) => openStore(feature.properties.id),
});
stores.setData(updated);
stores.remove();
```

## Search

```ts
const places = await map.search.search("صيدلية", {
  language: "ar",
  near: { lat: 31.95, lng: 35.91 },
  osmTags: ["amenity:pharmacy"],
  limit: 8,
  signal: abortController.signal,   // cancel stale requests while typing
});

const here = await map.search.reverse(31.95, 35.91, { language: "ar" });
console.log(here?.label, here?.adminAreas);
```

Use `new MapelevenSearch(hosted({ key }))` to search without a map.

## Without a bundler

The SDK is served from mapeleven.dev, versioned, so a plain HTML page works:

```html
<link rel="stylesheet" href="https://mapeleven.dev/sdk/web/0.3.0/mapeleven.css" />
<script type="importmap">
  { "imports": { "maplibre-gl": "https://cdn.jsdelivr.net/npm/maplibre-gl@6.16.0/dist/maplibre-gl.mjs" } }
</script>
<div id="map" style="height: 100vh"></div>
<script type="module">
  import { MapelevenMap, hosted } from "https://mapeleven.dev/sdk/web/0.3.0/mapeleven.js";
  new MapelevenMap("map", {
    provider: hosted({ key: "mel_..." }),
    workerUrl: "https://cdn.jsdelivr.net/npm/maplibre-gl@6.16.0/dist/maplibre-gl-worker.mjs",
  });
</script>
```

The [web starter](https://github.com/yehyatt/mapeleven-web-starter) is this page plus search and markers.
