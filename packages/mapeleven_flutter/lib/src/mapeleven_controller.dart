import 'dart:async';
import 'dart:math';
import 'dart:ui' show Color;

import 'package:maplibre_gl/maplibre_gl.dart';

import 'provider.dart';
import 'search.dart';

const _prefix = 'mapeleven-';
const _markersSource = '${_prefix}markers';
const _defaultColor = Color(0xFF0066FF);

/// Options for a GeoJSON layer drawn by [MapelevenController.addGeoJson].
class MapelevenGeoJsonOptions {
  const MapelevenGeoJsonOptions({this.cluster = false, this.color = _defaultColor, this.radius = 6, this.onTap});

  /// Group nearby points into numbered bubbles; tapping one zooms in.
  final bool cluster;
  final Color color;

  /// Point radius in logical pixels.
  final double radius;

  /// Called with the tapped feature's properties (not for clusters).
  final void Function(Map<String, dynamic> properties, LatLng position)? onTap;
}

/// A marker added with [MapelevenController.addMarker].
class MapelevenMarker {
  const MapelevenMarker({required this.id, required this.position, this.label, this.color = _defaultColor});

  final String id;
  final LatLng position;

  /// Text drawn under the pin.
  final String? label;
  final Color color;
}

/// Handle to the map once it is ready. Survives theme and language switches:
/// markers and GeoJSON layers are re-added after every style change.
class MapelevenController {
  MapelevenController.internal(this.raw, this.provider) : search = MapelevenSearch(provider) {
    raw.onFeatureTapped.add(_onFeatureTapped);
  }

  /// The underlying maplibre_gl controller, for anything Mapeleven does not wrap.
  final MapLibreMapController raw;
  final MapelevenProvider provider;
  final MapelevenSearch search;

  final Map<String, MapelevenMarker> _markers = {};
  final Map<String, (Map<String, dynamic>, MapelevenGeoJsonOptions)> _layers = {};
  final _markerTaps = StreamController<MapelevenMarker>.broadcast();
  bool _styleReady = false;
  int _markerSeq = 0;

  /// Emits when the user taps a marker.
  Stream<MapelevenMarker> get markerTaps => _markerTaps.stream;

  Future<void> flyTo(LatLng target, {double? zoom}) async {
    final z = zoom ?? max(raw.cameraPosition?.zoom ?? 14, 14);
    await raw.animateCamera(CameraUpdate.newLatLngZoom(target, z));
  }

  Future<void> fitBounds(LatLngBounds bounds, {double padding = 40}) async {
    await raw.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, left: padding, top: padding, right: padding, bottom: padding),
    );
  }

  /// Adds a pin; returns its id (pass your own [id] to update it later).
  Future<String> addMarker(LatLng position, {String? id, String? label, Color color = _defaultColor}) async {
    final markerId = id ?? 'm${_markerSeq++}';
    _markers[markerId] = MapelevenMarker(id: markerId, position: position, label: label, color: color);
    await _syncMarkers();
    return markerId;
  }

  Future<void> removeMarker(String id) async {
    if (_markers.remove(id) != null) await _syncMarkers();
  }

  Future<void> clearMarkers() async {
    _markers.clear();
    await _syncMarkers();
  }

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

  /// Called by [MapelevenMap] after each style load.
  Future<void> onStyleLoaded() async {
    _styleReady = true;
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
      FillLayerProperties(fillColor: color, fillOpacity: 0.2),
      filter: [
        '==',
        ['geometry-type'],
        'Polygon',
      ],
    );
    await raw.addLineLayer(
      id,
      '$id-line',
      LineLayerProperties(lineColor: color, lineWidth: 2),
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
        circleColor: color,
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
          'properties': {'mapelevenId': m.id, 'label': m.label ?? '', 'color': _hex(m.color)},
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
    );
    await raw.addSymbolLayer(
      _markersSource,
      '$_markersSource-label',
      SymbolLayerProperties(
        textField: ['get', 'label'],
        textFont: provider.fontStack,
        textSize: 13,
        textOffset: const [0, 1.4],
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
    if (layerId == '$_markersSource-pin') {
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

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
