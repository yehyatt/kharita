---
title: OpenStreetMap in Flutter
order: 8
description: How to show OpenStreetMap in a Flutter app, comparing flutter_map, maplibre_gl and Mapeleven, and why not to use the public OSM tile server and Nominatim in production.
---

# OpenStreetMap in Flutter

OpenStreetMap is free map data, not a map SDK. To show it in a Flutter app you need three more things: a Flutter widget that draws maps, a server that sends the map tiles, and a search service for addresses. This page compares the common ways to put those together.

## Do not ship with the public OSM servers

The tile server at `tile.openstreetmap.org` and the Nominatim search API are run by volunteers for light use. Their usage policies forbid heavy or bulk use, Nominatim allows at most one request per second and does not allow autocomplete, and neither offers any guarantee. They are fine for a quick test, not for an app in a store. Mapeleven never uses them.

## Three ways to do it

| | flutter_map | maplibre_gl | Mapeleven |
|---|---|---|---|
| What it is | A pure Dart map widget | Flutter bindings for MapLibre Native and GL JS | An SDK on top of maplibre_gl, plus a server |
| Tiles | Usually raster images; vector tiles through a plugin | Vector tiles | Vector tiles |
| Where tiles come from | You choose a provider | You choose a provider and a style | `hosted()`, your own server, or OpenFreeMap |
| Map styles | Set by the tile provider | A style JSON you write or pick | Five themes, Arabic or English labels |
| Search and addresses | Not included | Not included | Included (autocomplete and reverse geocoding) |
| Arabic and RTL labels | Depends on the tiles | Needs the RTL text plugin and a localised style | Handled for you |
| Markers with your own icons | Flutter widgets | Through symbol layers | `addMarker` with icons from PNGs or Material icons |
| Best for | Simple maps, full control in Dart | Teams that want to assemble their own stack | Apps that want the whole stack ready |

**flutter_map** is a good choice when you want simple maps and widgets as markers, and you already have a tile provider. You still need a tile service and a search service that allow production use.

**maplibre_gl** gives you smooth vector maps, rotation and smooth zoom. You assemble the rest: tiles, a style, fonts, the RTL text plugin and a search service. Mapeleven is built on it, and `map.raw` gives you the full maplibre_gl controller when you need it.

**Mapeleven** is maplibre_gl with those parts already chosen and wired together: a map server you can use or host, styles with Arabic and English labels, place search, marker icons, zones and clustering.

## Start in five minutes

```yaml
dependencies:
  mapeleven:
    git:
      url: https://github.com/yehyatt/mapeleven
      path: packages/mapeleven_flutter
      ref: v0.2.1
```

```dart
MapelevenMap(
  provider: MapelevenProvider.hosted(),
  initialCenter: const LatLng(31.9539, 35.9106),
  initialZoom: 13,
  onMapReady: (map) => map.addMarker(const LatLng(31.9539, 35.9106), label: 'Hello'),
)
```

The hosted server covers Jordan and the Gulf. For other countries use `MapelevenProvider.openFreeMap()` while you prototype, then [host your own server](self-hosting.md) for the region you need. Next: the [Flutter guide](flutter.md), or a ready app from the [starter repos](getting-started.md).

## Attribution

OpenStreetMap's licence (ODbL) requires visible credit wherever the map is shown. Mapeleven keeps the attribution button on; keep it visible and do not cover it with sheets or buttons.
