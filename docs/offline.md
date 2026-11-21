---
title: Offline maps
order: 4.97
description: Save a country or a city on the phone so the Flutter map works with no internet, in every theme and language, with MapLibre offline packs.
---

# Offline maps

A map that needs the internet is no use when the network is down. `MapelevenOffline` saves an area on the phone, and `MapelevenMap` then draws it with no connection at all. Android and iOS only; on the web, check `MapelevenOffline.isSupported` first.

```dart
final provider = MapelevenProvider.hosted(key: 'mel_...');

final pack = await MapelevenOffline.download(
  provider,
  MapelevenOfflineArea.jordan,
  maxZoom: 14,
  themes: const [MapelevenTheme.light, MapelevenTheme.dark],
  onProgress: (p) => print('${(p.fraction * 100).floor()}% ${p.bytes} bytes'),
);
```

Use the same provider, themes and languages as your `MapelevenMap`. The map finds saved tiles by their web address, so a map built from another provider or style will not see them.

## How big

| Area | `maxZoom` | Size |
|---|---|---|
| All of Jordan | 14: every street | about 100 MB |
| All of Jordan | 15: adds buildings, more shops and places | about 200 MB |
| One city (Irbid, Amman) | 15 | 3 to 10 MB |

The tiles are stored once. Each extra theme or language adds only its style, icons and fonts, about 1 MB. `MapelevenOffline.tileCount(bounds, maxZoom)` estimates the number of tiles before you start; keep zoom 15 for a city and zoom 14 for a country.

## Any area

```dart
final view = await controller.visibleBounds();
await MapelevenOffline.download(provider, MapelevenOfflineArea('Downtown', view), maxZoom: 15);
```

## Saved packs

```dart
final packs = await MapelevenOffline.packs();      // newest first, with size and status
await MapelevenOffline.resume(packs.first);         // finish one that stopped
await MapelevenOffline.delete(packs.first);         // free the space
```

A download stops when the app closes or the connection drops; the pack then shows `complete == false` and `resume` carries on from where it stopped. When the phone is online the map refreshes saved tiles as it shows them, so a pack does not go stale.

## What works offline

- The map, in every theme and language you saved.
- Your own markers, lines and the `MapelevenIcons`.
- Anything your app does with GPS and the compass.

Search, directions and satellite imagery still need the internet. The [Explorer demo](https://mapeleven.dev/explorer/) adds a hand-set position and a compass arrow for when GPS is down too, and the [print page](print.md) makes a paper map.

## API keys

On a server that checks keys, each saved tile counts towards the monthly allowance like a tile seen on the map. All of Jordan at zoom 14 is about 60,000 tiles.

## How it works

`MapelevenOffline` wraps MapLibre's offline packs. The first style downloads every tile in the area; each other theme and language downloads a one-tile region at the centre, which brings its style, icons and fonts. The packs live in MapLibre's offline database on the phone, outside the 50 MB browsing cache.
