# mapeleven

Open maps made simple for Flutter: OpenStreetMap + MapLibre with Arabic-first styles,
place search and a self-hostable tile server. Android, iOS and web.

```dart
MapelevenMap(
  provider: MapelevenProvider.openFreeMap(),   // or MapelevenProvider.selfHosted('https://maps.example.com')
  language: MapelevenLanguage.ar,
  onMapReady: (map) => map.addMarker(const LatLng(31.9539, 35.9106), label: 'عمّان'),
)
```

Full guide, server setup and roadmap: https://github.com/yehyatt/mapeleven

Map data © OpenStreetMap contributors (ODbL). Keep the attribution button visible.
