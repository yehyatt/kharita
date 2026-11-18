---
title: Satellite imagery
order: 4.8
description: Show satellite imagery under Mapeleven's roads and labels in Flutter and on the web, with your own Esri or MapTiler key.
---

# Satellite imagery

Mapeleven can show satellite imagery with its roads, borders and place names drawn on top, in Arabic or English. The imagery comes from a provider you choose, with your own key from that provider. It loads straight from them into your app: Mapeleven does not pass it through its servers and does not charge for it.

## Pick a provider

| Provider | Key from | Free use | After that |
|---|---|---|---|
| Esri World Imagery | [ArcGIS Location Platform](https://developers.arcgis.com/) (API key with the basemap privilege) | 2 million tiles a month | $0.15 per 1,000 tiles |
| MapTiler Satellite | [MapTiler Cloud](https://www.maptiler.com/cloud/) | Non-commercial use and prototypes | Paid plan for live commercial apps |
| Your own tiles | Any XYZ or TileJSON raster source | Your terms | Your terms |

Prices are from each provider's site at the time of writing; check their pricing pages. Each provider's terms apply, and the SDK adds its credit to the map's attribution for you.

## Flutter

```dart
MapelevenMap(
  provider: MapelevenProvider.hosted(key: 'mel_...'),
  imagery: MapelevenImagery.esri('YOUR_ARCGIS_KEY'), // or MapelevenImagery.mapTiler('...')
  initialCenter: const LatLng(31.9539, 35.9106),
  initialZoom: 15,
)
```

Set `imagery` to `null` to go back to the vector map in your `theme`. A satellite button is a `bool` in your state:

```dart
imagery: satellite ? MapelevenImagery.esri(arcgisKey) : null,
```

Markers, zones and other layers you added stay when you switch.

## Web

```js
import { MapelevenMap, hosted, esriImagery } from "mapeleven";

const map = new MapelevenMap("map", {
  provider: hosted({ key: "mel_..." }),
  imagery: esriImagery("YOUR_ARCGIS_KEY"), // or mapTilerImagery("...")
});

// Toggle later; your markers and GeoJSON layers are kept.
await map.setImagery(undefined);
await map.setImagery(esriImagery("YOUR_ARCGIS_KEY"));
```

## Your own imagery

Any raster tile source works, for example imagery your organisation licenses:

```dart
MapelevenImagery.custom(
  tiles: ['https://imagery.example.com/{z}/{x}/{y}.jpg'],
  attribution: 'Imagery © Example',
  maxZoom: 20,
)
```

```js
customImagery({ tiles: ["https://imagery.example.com/{z}/{x}/{y}.jpg"], attribution: "Imagery © Example", maxZoom: 20 });
```

## How it looks

Labels switch to white text on a dark outline, roads become light lines you can see through, and land, water and building fills are left out so the photo shows. Labels follow the map's language as usual.

## Keys in apps

Like your Mapeleven key, an imagery key ends up inside your app. Restrict it where the provider allows: Esri and MapTiler both let you limit a key to your websites (HTTP referrers), and set a monthly budget or usage alert in their dashboard.
