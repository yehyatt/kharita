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

## Get an Esri key

1. Sign up for a free ArcGIS Location Platform account at [location.arcgis.com/sign-up](https://location.arcgis.com/sign-up/).
2. At [developers.arcgis.com](https://developers.arcgis.com/), open **Content**, then **New item**, then **Developer credentials**.
3. Choose **Public application**. The two private options give access to your whole account and must never ship in an app or website.
4. Keep **No item access**, and under location services tick **Basemaps** only.
5. Pick an expiry date and note it: imagery stops loading when the key expires, until you create a new one.
6. Copy the key when it is shown. Keep it in your app's configuration or build settings, not in your source repository.

## Keys in apps

An imagery key ends up inside your app or web page, where anyone can read it. Make two keys:

| Key | Use it in | Referrers |
|---|---|---|
| Web key | Your website | Your domain, for example `https://example.com` |
| App key | Your Flutter iOS and Android builds | None |

Native apps do not send a website address with their requests, so a key limited to referrers may stop working in them. Keeping the app key separate means a referrer limit on the web key never breaks your app, and the provider's usage page shows web and app use apart.

A referrer limit stops casual reuse of your key, but a determined person can fake the header. To avoid surprise bills, set a usage alert in the provider's dashboard, and check in your account's billing settings what happens when you pass the free allowance.

In Flutter, pass the key at build time rather than writing it in code:

```bash
flutter build ios --dart-define=ESRI_KEY=...
```

```dart
const esriKey = String.fromEnvironment('ESRI_KEY');
// imagery: satellite && esriKey.isNotEmpty ? MapelevenImagery.esri(esriKey) : null,
```
