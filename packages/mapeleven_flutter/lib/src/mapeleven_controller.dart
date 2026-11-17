import 'dart:async';
import 'dart:math';
import 'dart:ui' show Color, Rect;

import 'package:maplibre_gl/maplibre_gl.dart';

import 'icons.dart';
import 'provider.dart';
import 'search.dart';

const _prefix = 'mapeleven-';
const _markersSource = '${_prefix}markers';
const _defaultColor = Color(0xFF0066FF);

/// Options for a GeoJSON layer drawn by [MapelevenController.addGeoJson].
class MapelevenGeoJsonOptions {
  const MapelevenGeoJsonOptions({
    this.cluster = false,
    this.color = _defaultColor,
    this.radius = 6,
    this.lineWidth = 2,
    this.fillOpacity = 0.2,
    this.dashed = false,
    this.onTap,
  });

  /// Group nearby points into numbered bubbles; tapping one zooms in.
  final bool cluster;
  final Color color;

  /// Point radius in logical pixels.
  final double radius;
  final double lineWidth;

  /// Opacity of polygon fills (0 hides the fill, the outline stays).
  final double fillOpacity;

  /// Draw lines and outlines dashed, for planned routes or soft boundaries.
  final bool dashed;

  /// Called with the tapped feature's properties (not for clusters).
  final void Function(Map<String, dynamic> properties, LatLng position)? onTap;
}

/// A marker added with [MapelevenController.addMarker].
class MapelevenMarker {
  const MapelevenMarker({
    required this.id,
    required this.position,
    this.label,
    this.color = _defaultColor,
    this.icon,
    this.rotation = 0,
    this.anchor = MapelevenAnchor.center,
    this.data,
  });

  final String id;
  final LatLng position;

  /// Text drawn under the marker.
  final String? label;

  /// Dot colour when no [icon] is set.
  final Color color;

  /// Name of an icon registered with [MapelevenController.registerIcon].
  final String? icon;

  /// Clockwise rotation in degrees, relative to north (vehicle heading).
  final double rotation;
  final MapelevenAnchor anchor;

  /// Anything you want back when the marker is tapped.
  final Object? data;

  MapelevenMarker copyWith({LatLng? position, double? rotation, String? label}) => MapelevenMarker(
    id: id,
    position: position ?? this.position,
    label: label ?? this.label,
    color: color,
    icon: icon,
    rotation: rotation ?? this.rotation,
    anchor: anchor,
    data: data,
  );
}

/// A point of interest drawn by the basemap (shop, café, mosque, park...).
class MapelevenPoi {
  const MapelevenPoi({required this.name, required this.position, this.kind, this.properties = const {}});

  /// Name in the map's language when the data has one.
  final String name;
  final LatLng position;

  /// Category such as `cafe`, `pharmacy`, `school` (OSM-derived).
  final String? kind;
  final Map<String, dynamic> properties;
}

/// Handle to the map once it is ready. Survives theme and language switches:
/// icons, markers and GeoJSON layers are re-added after every style change.
class MapelevenController {
  MapelevenController.internal(this.raw, this.provider, {this.language = MapelevenLanguage.ar})
    : search = MapelevenSearch(provider) {
    raw.onFeatureTapped.add(_onFeatureTapped);
  }

  /// The underlying maplibre_gl controller, for anything Mapeleven does not wrap.
  final MapLibreMapController raw;
  final MapelevenProvider provider;
  final MapelevenSearch search;

  /// Current label language; kept in sync by [MapelevenMap].
  MapelevenLanguage language;

  final Map<String, MapelevenIcon> _icons = {};
  final Map<String, MapelevenMarker> _markers = {};
  final Map<String, (Map<String, dynamic>, MapelevenGeoJsonOptions)> _layers = {};
  final _markerTaps = StreamController<MapelevenMarker>.broadcast();
  bool _styleReady = false;
  int _markerSeq = 0;
  List<String> _poiLayers = const [];

  /// Emits when the user taps a marker.
  Stream<MapelevenMarker> get markerTaps => _markerTaps.stream;

  /// Markers currently on the map, by id.
  Map<String, MapelevenMarker> get markers => Map.unmodifiable(_markers);

  // ── Camera ────────────────────────────────────────────────────────────────

  /// Centre of the map right now.
  LatLng? get center => raw.cameraPosition?.target;
  double? get zoom => raw.cameraPosition?.zoom;

  /// Animates to [target]; keeps the zoom unless it is below 14.
  Future<void> flyTo(LatLng target, {double? zoom}) async {
    final z = zoom ?? max(raw.cameraPosition?.zoom ?? 14, 14);
    await raw.animateCamera(CameraUpdate.newLatLngZoom(target, z));
  }

  /// Jumps to [target] without animation.
  Future<void> moveTo(LatLng target, {double? zoom}) async {
    await raw.moveCamera(zoom == null ? CameraUpdate.newLatLng(target) : CameraUpdate.newLatLngZoom(target, zoom));
  }

  Future<void> fitBounds(LatLngBounds bounds, {double padding = 40}) async {
    await raw.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, left: padding, top: padding, right: padding, bottom: padding),
    );
  }

  /// Fits all [points] on screen (for example a driver and a delivery address).
  Future<void> fitPoints(List<LatLng> points, {double padding = 64, double maxZoom = 16}) async {
    if (points.isEmpty) return;
    if (points.length == 1) return flyTo(points.first, zoom: maxZoom);
    final lats = points.map((p) => p.latitude);
    final lngs = points.map((p) => p.longitude);
    await fitBounds(
      LatLngBounds(
        southwest: LatLng(lats.reduce(min), lngs.reduce(min)),
        northeast: LatLng(lats.reduce(max), lngs.reduce(max)),
      ),
      padding: padding,
    );
    if ((raw.cameraPosition?.zoom ?? 0) > maxZoom) await raw.animateCamera(CameraUpdate.zoomTo(maxZoom));
  }

  // ── Icons and markers ─────────────────────────────────────────────────────

  /// Makes [icon] available to markers by its name.
  Future<void> registerIcon(MapelevenIcon icon) async {
    _icons[icon.name] = icon;
    if (_styleReady) await raw.addImage('$_prefix${icon.name}', icon.png, false, icon.pixelRatio);
  }

  /// Adds a marker, or updates it if [id] already exists; returns its id.
  Future<String> addMarker(
    LatLng position, {
    String? id,
    String? label,
    Color color = _defaultColor,
    String? icon,
    double rotation = 0,
    MapelevenAnchor anchor = MapelevenAnchor.center,
    Object? data,
  }) async {
    final markerId = id ?? 'm${_markerSeq++}';
    _markers[markerId] = MapelevenMarker(
      id: markerId,
      position: position,
      label: label,
      color: color,
      icon: icon,
      rotation: rotation,
      anchor: anchor,
      data: data,
    );
    await _syncMarkers();
    return markerId;
  }

  /// Moves an existing marker (live vehicles). Pass [rotation] to turn it.
  Future<void> moveMarker(String id, LatLng position, {double? rotation}) async {
    final m = _markers[id];
    if (m == null) return;
    _markers[id] = m.copyWith(position: position, rotation: rotation);
    await _syncMarkers();
  }

  Future<void> removeMarker(String id) async {
    if (_markers.remove(id) != null) await _syncMarkers();
  }

  Future<void> clearMarkers() async {
    _markers.clear();
    await _syncMarkers();
  }

  // ── GeoJSON layers ────────────────────────────────────────────────────────

  /// Draws points, lines and polygons from a GeoJSON map, optionally clustered.
  Future<void> addGeoJson(
    String name,
    Map<String, dynamic> data, {
    MapelevenGeoJsonOptions options = const MapelevenGeoJsonOptions(),
  }) async {
    await removeGeoJson(name);
    _layers[name] = (data, options);
    if (_styleReady) await _installLayer(name, data, options);
  }

  Future<void> setGeoJsonData(String name, Map<String, dynamic> data) async {
    final entry = _layers[name];
    if (entry == null) throw StateError('No GeoJSON layer "$name"');
    _layers[name] = (data, entry.$2);
    if (_styleReady) await raw.setGeoJsonSource('$_prefix$name', data);
  }

  Future<void> removeGeoJson(String name) async {
    if (_layers.remove(name) == null || !_styleReady) return;
    final id = '$_prefix$name';
    for (final suffix in const ['count', 'cluster', 'point', 'line', 'fill']) {
      await raw.removeLayer('$id-$suffix').catchError((_) {});
    }
    await raw.removeSource(id).catchError((_) {});
  }

  // ── Basemap places ────────────────────────────────────────────────────────

  /// The basemap point of interest under a screen [point] (from a tap), if any.
  Future<MapelevenPoi?> poiAt(Point<double> point) async {
    if (!_styleReady || _poiLayers.isEmpty) return null;
    final features = await raw.queryRenderedFeatures(point, _poiLayers, null);
    for (final f in features) {
      final poi = _toPoi(f);
      if (poi != null) return poi;
    }
    return null;
  }

  /// Named points of interest drawn in the visible area, nearest the centre first.
  Future<List<MapelevenPoi>> visiblePois({String? kind, int limit = 50}) async {
    if (!_styleReady || _poiLayers.isEmpty) return const [];
    final features = await raw.queryRenderedFeaturesInRect(const Rect.fromLTRB(0, 0, 100000, 100000), _poiLayers, null);
    final seen = <String>{};
    final pois = <MapelevenPoi>[];
    for (final f in features) {
      final poi = _toPoi(f);
      if (poi == null || (kind != null && poi.kind != kind)) continue;
      if (seen.add('${poi.name}|${poi.position.latitude.toStringAsFixed(5)}')) pois.add(poi);
    }
    final c = center;
    if (c != null) pois.sort((a, b) => _dist2(a.position, c).compareTo(_dist2(b.position, c)));
    return pois.take(limit).toList();
  }

  /// Every point of interest in the visible area, including ones whose labels
  /// the map hid to avoid overlap, nearest the centre first. Reads the loaded
  /// tiles, so it is instant and works offline. [kinds] filters by category
  /// (`{'pharmacy', 'chemist'}`); see [MapelevenPoi.kind].
  Future<List<MapelevenPoi>> nearbyPois({Set<String>? kinds, int limit = 100}) async {
    final source = provider.poiSource;
    if (!_styleReady || source == null) return visiblePois(limit: limit);
    final bounds = await raw.getVisibleRegion();
    final features = await raw.querySourceFeatures(source.$1, source.$2, null);
    final seen = <String>{};
    final pois = <MapelevenPoi>[];
    for (final f in features) {
      final poi = _toPoi(f);
      if (poi == null || (kinds != null && !kinds.contains(poi.kind))) continue;
      final p = poi.position;
      if (p.latitude < bounds.southwest.latitude ||
          p.latitude > bounds.northeast.latitude ||
          p.longitude < bounds.southwest.longitude ||
          p.longitude > bounds.northeast.longitude) {
        continue;
      }
      // The same place repeats in every tile that buffers it.
      if (seen.add('${poi.name}|${p.latitude.toStringAsFixed(4)}|${p.longitude.toStringAsFixed(4)}')) pois.add(poi);
    }
    final c = center;
    if (c != null) pois.sort((a, b) => _dist2(a.position, c).compareTo(_dist2(b.position, c)));
    return pois.take(limit).toList();
  }

  MapelevenPoi? _toPoi(Object? feature) {
    if (feature is! Map) return null;
    final props = Map<String, dynamic>.from((feature['properties'] as Map?) ?? const {});
    final geometry = feature['geometry'] as Map?;
    if (geometry == null || geometry['type'] != 'Point') return null;
    final name = props['name:${language.name}'] ?? props['name'];
    if (name == null || '$name'.isEmpty) return null;
    final coords = geometry['coordinates'] as List;
    return MapelevenPoi(
      name: '$name',
      position: LatLng((coords[1] as num).toDouble(), (coords[0] as num).toDouble()),
      // Protomaps tiles call it `kind`, OpenMapTiles `subclass`/`class`.
      kind: (props['kind'] ?? props['subclass'] ?? props['class'])?.toString(),
      properties: props,
    );
  }

  // ── Lifecycle (called by MapelevenMap) ────────────────────────────────────

  /// Called by [MapelevenMap] after each style load.
  Future<void> onStyleLoaded() async {
    _styleReady = true;
    final ids = (await raw.getLayerIds()).map((e) => '$e');
    _poiLayers = ids.where((id) => id == 'pois' || id.startsWith('poi')).toList();
    for (final icon in _icons.values) {
      await raw.addImage('$_prefix${icon.name}', icon.png, false, icon.pixelRatio);
    }
    for (final MapEntry(key: name, value: (data, options)) in _layers.entries) {
      await _installLayer(name, data, options);
    }
    await _installMarkers();
  }

  /// Called by [MapelevenMap] before the style changes.
  void onStyleChanging() => _styleReady = false;

  void dispose() {
    raw.onFeatureTapped.remove(_onFeatureTapped);
    _markerTaps.close();
    search.close();
  }

  Future<void> _installLayer(String name, Map<String, dynamic> data, MapelevenGeoJsonOptions o) async {
    final id = '$_prefix$name';
    final color = _hex(o.color);
    await raw.addSource(
      id,
      GeojsonSourceProperties(data: data, cluster: o.cluster, clusterRadius: 50, clusterMaxZoom: 14),
    );
    await raw.addFillLayer(
      id,
      '$id-fill',
      FillLayerProperties(fillColor: color, fillOpacity: o.fillOpacity),
      filter: [
        '==',
        ['geometry-type'],
        'Polygon',
      ],
    );
    await raw.addLineLayer(
      id,
      '$id-line',
      LineLayerProperties(
        lineColor: color,
        lineWidth: o.lineWidth,
        lineCap: 'round',
        lineJoin: 'round',
        lineDasharray: o.dashed ? const [2, 2] : null,
      ),
      filter: [
        'in',
        ['geometry-type'],
        [
          'literal',
          ['LineString', 'Polygon'],
        ],
      ],
      enableInteraction: false,
    );
    await raw.addCircleLayer(
      id,
      '$id-point',
      CircleLayerProperties(
        circleColor: [
          'coalesce',
          ['get', 'color'],
          color,
        ],
        circleRadius: o.radius,
        circleStrokeColor: '#ffffff',
        circleStrokeWidth: 2,
      ),
      filter: [
        'all',
        [
          '==',
          ['geometry-type'],
          'Point',
        ],
        [
          '!',
          ['has', 'point_count'],
        ],
      ],
    );
    if (o.cluster) {
      await raw.addCircleLayer(
        id,
        '$id-cluster',
        CircleLayerProperties(
          circleColor: color,
          circleOpacity: 0.85,
          circleRadius: [
            'step',
            ['get', 'point_count'],
            16,
            10,
            20,
            50,
            26,
          ],
          circleStrokeColor: '#ffffff',
          circleStrokeWidth: 2,
        ),
        filter: ['has', 'point_count'],
      );
      await raw.addSymbolLayer(
        id,
        '$id-count',
        SymbolLayerProperties(
          textField: ['get', 'point_count_abbreviated'],
          textFont: provider.fontStack,
          textSize: 12,
          textColor: '#ffffff',
          textAllowOverlap: true,
        ),
        filter: ['has', 'point_count'],
        enableInteraction: false,
      );
    }
  }

  Map<String, dynamic> _markersGeoJson() => {
    'type': 'FeatureCollection',
    'features': [
      for (final m in _markers.values)
        {
          'type': 'Feature',
          'id': m.id,
          'properties': {
            'mapelevenId': m.id,
            'label': m.label ?? '',
            'color': _hex(m.color),
            'icon': m.icon == null ? '' : '$_prefix${m.icon}',
            'rotation': m.rotation,
            'anchor': m.anchor.name,
          },
          'geometry': {
            'type': 'Point',
            'coordinates': [m.position.longitude, m.position.latitude],
          },
        },
    ],
  };

  Future<void> _installMarkers() async {
    await raw.addGeoJsonSource(_markersSource, _markersGeoJson());
    await raw.addCircleLayer(
      _markersSource,
      '$_markersSource-pin',
      const CircleLayerProperties(
        circleColor: ['get', 'color'],
        circleRadius: 9,
        circleStrokeColor: '#ffffff',
        circleStrokeWidth: 3,
      ),
      filter: [
        '==',
        ['get', 'icon'],
        '',
      ],
    );
    await raw.addSymbolLayer(
      _markersSource,
      '$_markersSource-icon',
      const SymbolLayerProperties(
        iconImage: ['get', 'icon'],
        iconRotate: ['get', 'rotation'],
        iconAnchor: ['get', 'anchor'],
        iconRotationAlignment: 'map',
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
      ),
      filter: [
        '!=',
        ['get', 'icon'],
        '',
      ],
    );
    await raw.addSymbolLayer(
      _markersSource,
      '$_markersSource-label',
      SymbolLayerProperties(
        textField: ['get', 'label'],
        textFont: provider.fontStack,
        textSize: 13,
        textOffset: const [0, 1.6],
        textAnchor: 'top',
        textColor: '#0A1628',
        textHaloColor: '#ffffff',
        textHaloWidth: 1.5,
      ),
      enableInteraction: false,
    );
  }

  Future<void> _syncMarkers() async {
    if (_styleReady) await raw.setGeoJsonSource(_markersSource, _markersGeoJson());
  }

  Future<void> _onFeatureTapped(Point<double> point, LatLng latLng, String id, String layerId, Annotation? _) async {
    if (layerId == '$_markersSource-pin' || layerId == '$_markersSource-icon') {
      final marker = _markers[id];
      if (marker != null) _markerTaps.add(marker);
      return;
    }
    if (!layerId.startsWith(_prefix)) return;
    final name = layerId.substring(_prefix.length, layerId.lastIndexOf('-'));
    final entry = _layers[name];
    if (entry == null) return;
    final features = await raw.queryRenderedFeatures(point, [layerId], null);
    if (features.isEmpty) return;
    final props = Map<String, dynamic>.from(((features.first as Map)['properties'] as Map?) ?? const {});
    if (layerId.endsWith('-cluster')) {
      final zoom = await raw.getClusterExpansionZoom('$_prefix$name', (props['cluster_id'] as num).toInt());
      await raw.animateCamera(CameraUpdate.newLatLngZoom(latLng, zoom + 0.5));
    } else {
      entry.$2.onTap?.call(props, latLng);
    }
  }
}

double _dist2(LatLng a, LatLng b) => pow(a.latitude - b.latitude, 2) + pow(a.longitude - b.longitude, 2).toDouble();

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
