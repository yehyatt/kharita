---
title: Flutter guide
order: 2
---

# Flutter guide

Everything here runs on Android, iOS and Flutter web from the same code.

## The map widget

```dart
MapelevenMap(
  provider: MapelevenProvider.hosted(key: 'mel_...'), // free key: mapeleven.dev/account
  language: MapelevenLanguage.ar,      // optional: defaults to the app's language
  theme: MapelevenTheme.light,         // light, dark, white, grayscale, black
  initialCenter: const LatLng(31.9539, 35.9106),
  initialZoom: 13,
  showUserLocation: true,              // your app must hold location permission
  compassEnabled: true,
  onMapReady: (map) { /* MapelevenController */ },
  onTap: (latLng) {},
  onLongPress: (latLng) {},
  onPoiTap: (poi) {},                  // a shop, café, mosque... on the basemap
  onCameraIdle: (center, zoom) {},     // the camera stopped moving
)
```

`onMapReady` hands you a `MapelevenController`. Keep it in your state; it survives theme and language changes.

## Camera

```dart
await map.flyTo(const LatLng(31.95, 35.91), zoom: 16);   // animated
await map.moveTo(const LatLng(31.95, 35.91));            // instant
await map.fitPoints([driver, customer], padding: 80);    // frame several points
await map.fitBounds(bounds);
final center = map.center;                               // LatLng?
final zoom = map.zoom;
```

## Markers

```dart
await map.addMarker(position, id: 'shop-12', label: 'Branch 12', color: Colors.teal);
await map.moveMarker('shop-12', newPosition);            // live updates
await map.removeMarker('shop-12');
map.markerTaps.listen((marker) => print(marker.id));
```

Calling `addMarker` with an existing `id` updates that marker. Pass `data:` to get any object back on tap.

### Your own icons

Register an icon once, then use its name on any number of markers.

```dart
// A Material icon on a coloured disc (vehicles, categories).
await map.registerIcon(await MapelevenIcon.fromIconData('truck', Icons.local_shipping, background: Colors.orange));

// A teardrop pin; anchor it at the tip.
await map.registerIcon(await MapelevenIcon.pin('home', color: Colors.teal, icon: Icons.home));

// Any PNG (pixelRatio 3 means a 120 px image shows at 40 points).
await map.registerIcon(MapelevenIcon('logo', pngBytes, pixelRatio: 3));

await map.addMarker(driver, id: 'driver', icon: 'truck');
await map.addMarker(address, id: 'home', icon: 'home', anchor: MapelevenAnchor.bottom);
await map.addMarker(car, id: 'car', icon: 'arrow', rotation: headingDegrees); // turns with the heading
```

## Search and reverse geocoding

```dart
// As the user types (debounce about 250 ms), ranked near the map centre.
final places = await map.search.search('صيدلية', language: MapelevenLanguage.ar, near: map.center);

// Only one category, only inside a box.
final pharmacies = await map.search.search('pharmacy', osmTags: ['amenity:pharmacy'], bounds: jordanBounds);

// What is at this point?
final place = await map.search.reverse(latLng, language: MapelevenLanguage.ar);
print(place?.label());       // name and address on one line
print(place?.adminAreas);    // [district, locality, city, county, state], most specific first
```

A `MapelevenPlace` has `name`, `address`, `position`, `type` (OSM category), `street`, `houseNumber`, `postcode`, `district`, `locality`, `city`, `county`, `state`, `country`, `countryCode`, `bounds` (for areas) and `osmId`.

Search works anywhere with `MapelevenSearch(provider)`, without a map, for example in a form or a background job.

## Places on the basemap

The basemap already shows shops, cafés, pharmacies, mosques, hospitals, fuel stations, banks and more. You can use them without any server call:

```dart
// Tap handling: opens your own place sheet.
MapelevenMap(onPoiTap: (poi) => showPlace(poi.name, poi.kind, poi.position));

// Everything of a kind in the visible area, nearest the centre first.
final nearby = await map.nearbyPois(kinds: {'pharmacy', 'chemist'});
```

`poi.kind` uses OpenStreetMap values such as `restaurant`, `fast_food`, `cafe`, `pharmacy`, `hospital`, `clinic`, `fuel`, `atm`, `bank`, `place_of_worship`, `supermarket`, `hotel`.

## GeoJSON layers

Points, lines and polygons, with optional clustering and tap handlers.

```dart
await map.addGeoJson('branches', branchesGeoJson,
    options: MapelevenGeoJsonOptions(cluster: true, color: Colors.teal, onTap: (props, latLng) {}));

await map.addGeoJson('zone', zonePolygon,
    options: const MapelevenGeoJsonOptions(color: Colors.teal, fillOpacity: 0.08, dashed: true));

await map.addGeoJson('route', lineString,
    options: const MapelevenGeoJsonOptions(color: Colors.blue, lineWidth: 5));

await map.setGeoJsonData('route', updatedLine);   // update in place
await map.removeGeoJson('zone');
```

A point feature with a `color` property (for example `"#DC2626"`) is drawn in that colour.

## Anything else

`map.raw` is the underlying `MapLibreMapController` from [maplibre_gl](https://pub.dev/packages/maplibre_gl), for features Mapeleven does not wrap yet. Layers you add there with ids that do not start with `mapeleven-` are not restored after a theme change.

## Testing

`MapelevenMap` needs a platform view, which `flutter test` does not provide. Hide the map behind a flag in widget tests and test your own logic (for example the code that turns a `MapelevenPlace` into your address model) without it.
