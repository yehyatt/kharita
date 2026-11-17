---
title: Delivery recipes
order: 3
---

# Delivery recipes

Three patterns most delivery and on-demand apps need. The [Explorer demo](/explorer/) runs all three (Delivery tab), and its source is in [`apps/explorer`](https://github.com/yehyatt/mapeleven/tree/main/apps/explorer).

## 1. Address picker with a fixed centre pin

The pin stays in the middle of the screen; the customer moves the map under it. When the map stops, reverse geocode the centre.

```dart
Stack(children: [
  MapelevenMap(
    provider: MapelevenProvider.hosted(),
    initialCenter: lastKnownOrCityCentre,
    initialZoom: 16,
    onMapReady: (map) => _map = map,
    onCameraIdle: (center, zoom) async {
      setState(() => _pin = center);
      final place = await _map!.search.reverse(center, language: MapelevenLanguage.ar);
      setState(() => _address = place?.label());
    },
  ),
  const IgnorePointer(child: Center(child: Padding(
    padding: EdgeInsets.only(bottom: 44),          // puts the pin's tip on the centre
    child: Icon(Icons.location_on, size: 48),
  ))),
]);
```

Tips:

- Debounce is built in: `onCameraIdle` fires once per gesture. Ignore late answers by keeping a request counter.
- Store the coordinates, not only the text. The coordinates are the source of truth for the driver.
- The "My location" button is `map.flyTo(await yourLocation())`; the next `onCameraIdle` updates the address.

## 2. Delivery zones

Draw the zone and check the pin against it in your app (or on your backend).

```dart
await map.addGeoJson('zone', zoneFeature,
    options: const MapelevenGeoJsonOptions(color: Colors.teal, fillOpacity: 0.06, dashed: true));

bool inZone(LatLng p, List<List<double>> ring) {          // ring: [[lng, lat], ...]
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final xi = ring[i][0], yi = ring[i][1], xj = ring[j][0], yj = ring[j][1];
    if ((yi > p.latitude) != (yj > p.latitude) &&
        p.longitude < (xj - xi) * (p.latitude - yi) / (yj - yi) + xi) inside = !inside;
  }
  return inside;
}
```

If your zones are defined by neighbourhood names instead of polygons, use `place.adminAreas` from reverse geocoding: it lists the district, locality, city, county and governorate, most specific first, in the language you asked for.

## 3. Live driver tracking

Register a vehicle icon once, then move the marker each time a position arrives (WebSocket, push, polling).

```dart
await map.registerIcon(await MapelevenIcon.fromIconData('truck', Icons.local_shipping, background: Colors.orange));
await map.registerIcon(await MapelevenIcon.pin('home', color: Colors.teal, icon: Icons.home));
await map.addMarker(address, id: 'home', icon: 'home', anchor: MapelevenAnchor.bottom);

socket.positions.listen((driver) async {
  await map.addMarker(driver, id: 'driver', icon: 'truck');   // add or move
  await map.fitPoints([driver, address], padding: 72);
});
```

For a straight-line distance under the map, use the haversine formula; for a road ETA you need routing, which is on the [roadmap](https://github.com/yehyatt/mapeleven/blob/main/docs/ROADMAP.md).

## 4. Distributors and stores

Hundreds of points stay fast with clustering; taps on clusters zoom in automatically.

```dart
await map.addGeoJson('stores', storesFeatureCollection,
    options: MapelevenGeoJsonOptions(cluster: true, color: Colors.blueGrey,
        onTap: (props, latLng) => openStore(props['id'])));
```

## Opening turn-by-turn navigation

Until in-app routing ships, hand the driver to the phone's navigation app:

```dart
final uri = Platform.isIOS
    ? Uri.parse('https://maps.apple.com/?daddr=$lat,$lng')
    : Uri.parse('geo:$lat,$lng?q=$lat,$lng');
await launchUrl(uri, mode: LaunchMode.externalApplication);
```
