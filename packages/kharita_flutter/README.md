# kharita

Open maps made simple for Flutter: OpenStreetMap + MapLibre with Arabic-first styles,
place search and a self-hostable tile server. Android, iOS and web.

```dart
KharitaMap(
  provider: KharitaProvider.openFreeMap(),   // or KharitaProvider.selfHosted('https://maps.example.com')
  language: KharitaLanguage.ar,
  onMapReady: (map) => map.addMarker(const LatLng(31.9539, 35.9106), label: 'عمّان'),
)
```

Full guide, server setup and roadmap: https://github.com/yehyatt/kharita

Map data © OpenStreetMap contributors (ODbL). Keep the attribution button visible.
