import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mapeleven/mapeleven.dart';

// --dart-define=MAPELEVEN_SERVER=https://maps.example.com uses your own server; otherwise OpenFreeMap.
const _server = String.fromEnvironment('MAPELEVEN_SERVER');

void main() => runApp(const MapelevenExampleApp());

class MapelevenExampleApp extends StatelessWidget {
  const MapelevenExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Mapeleven',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: const Color(0xFF0066FF), fontFamily: 'Arial'),
        home: const MapScreen(),
      );
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _provider = _server.isEmpty ? MapelevenProvider.openFreeMap() : MapelevenProvider.selfHosted(_server);
  final _query = TextEditingController();
  MapelevenController? _map;
  var _language = MapelevenLanguage.ar;
  var _theme = MapelevenTheme.light;
  List<MapelevenPlace> _results = const [];
  Timer? _debounce;

  bool get _ar => _language == MapelevenLanguage.ar;

  void _onReady(MapelevenController map) {
    _map = map;
    // Synthetic sample data: 60 points scattered around Amman, clustered.
    final r = Random(42);
    map.addGeoJson(
      'sites',
      {
        'type': 'FeatureCollection',
        'features': [
          for (var i = 0; i < 60; i++)
            {
              'type': 'Feature',
              'properties': {'name': 'Sample site ${i + 1}'},
              'geometry': {
                'type': 'Point',
                'coordinates': [35.85 + r.nextDouble() * 0.15, 31.9 + r.nextDouble() * 0.1],
              },
            },
        ],
      },
      options: MapelevenGeoJsonOptions(
        cluster: true,
        color: const Color(0xFF00D4AA),
        onTap: (props, _) => _toast('${props['name']}'),
      ),
    );
    map.addMarker(const LatLng(31.9539, 35.9106), label: 'عمّان');
    map.markerTaps.listen((m) => _toast(m.label ?? m.id));
  }

  void _onQuery(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final map = _map;
      if (map == null) return;
      try {
        final results = await map.search.search(text, language: _language, near: map.raw.cameraPosition?.target);
        if (mounted && _query.text == text) setState(() => _results = results);
      } catch (e) {
        _toast('$e');
      }
    });
  }

  Future<void> _pick(MapelevenPlace place) async {
    setState(() => _results = const []);
    _query.text = place.name;
    FocusScope.of(context).unfocus();
    final bounds = place.bounds;
    if (bounds != null) {
      await _map?.fitBounds(bounds);
    } else {
      await _map?.flyTo(place.position, zoom: 16);
    }
  }

  Future<void> _whatIsHere(LatLng position) async {
    final place = await _map?.search.reverse(position, language: _language);
    if (place == null) return;
    await _map?.addMarker(position, label: place.name, color: const Color(0xFF1E293B));
    _toast(place.label(_ar ? '، ' : ', '));
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: Stack(
          children: [
            MapelevenMap(
              provider: _provider,
              language: _language,
              theme: _theme,
              onMapReady: _onReady,
              onLongPress: _whatIsHere,
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Material(
                            elevation: 3,
                            borderRadius: BorderRadius.circular(12),
                            child: TextField(
                              controller: _query,
                              onChanged: _onQuery,
                              decoration: InputDecoration(
                                hintText: _ar ? 'ابحث عن مكان' : 'Search for a place',
                                prefixIcon: const Icon(Icons.search),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _Pill(
                          label: _ar ? 'EN' : 'ع',
                          onTap: () => setState(() => _language = _ar ? MapelevenLanguage.en : MapelevenLanguage.ar),
                        ),
                        const SizedBox(width: 6),
                        _Pill(
                          icon: _theme == MapelevenTheme.dark ? Icons.light_mode : Icons.dark_mode,
                          onTap: () => setState(
                            () => _theme = _theme == MapelevenTheme.dark ? MapelevenTheme.light : MapelevenTheme.dark,
                          ),
                        ),
                      ],
                    ),
                    if (_results.isNotEmpty)
                      Card(
                        margin: const EdgeInsets.only(top: 6),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 320),
                          child: ListView(
                            shrinkWrap: true,
                            children: [
                              for (final p in _results)
                                ListTile(
                                  dense: true,
                                  title: Text(p.name),
                                  subtitle: Text(p.address, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  onTap: () => _pick(p),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({this.label, this.icon, required this.onTap});

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF0A1628),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: icon != null
                  ? Icon(icon, color: Colors.white, size: 20)
                  : Text(label!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      );
}
