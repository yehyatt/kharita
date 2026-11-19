import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';

import 'provider.dart';

/// How the route is travelled.
enum MapelevenTravelMode {
  car('auto'),
  walk('pedestrian'),
  bike('bicycle');

  const MapelevenTravelMode(this.costing);

  /// Valhalla costing model.
  final String costing;
}

/// What the traveller does at a step.
enum MapelevenManeuver {
  start,
  arrive,
  continueStraight,
  slightRight,
  right,
  sharpRight,
  uTurn,
  sharpLeft,
  left,
  slightLeft,
  rampRight,
  rampLeft,
  exitRight,
  exitLeft,
  keepRight,
  keepLeft,
  merge,
  roundabout,
  ferry,
  other,
}

/// One instruction of a [MapelevenRoute].
class MapelevenStep {
  const MapelevenStep({
    required this.maneuver,
    required this.instruction,
    required this.distanceMeters,
    required this.duration,
    required this.position,
    this.streetNames = const [],
    this.roundaboutExit,
  });

  final MapelevenManeuver maneuver;

  /// Ready-to-show text in the requested language, e.g. "Turn right onto
  /// King Hussein Street" or "انعطف يمينًا إلى شارع الملك الحسين".
  final String instruction;

  /// Length of this step (until the next instruction).
  final double distanceMeters;
  final Duration duration;

  /// Where the maneuver happens.
  final LatLng position;

  /// Street names after the maneuver, as OpenStreetMap has them.
  final List<String> streetNames;

  /// Which exit to take, for [MapelevenManeuver.roundabout].
  final int? roundaboutExit;
}

/// A route between two or more stops, from [MapelevenRouter.route].
class MapelevenRoute {
  const MapelevenRoute({
    required this.mode,
    required this.distanceMeters,
    required this.duration,
    required this.points,
    required this.steps,
  });

  final MapelevenTravelMode mode;
  final double distanceMeters;

  /// Travel time from road types and speed limits, without live traffic.
  final Duration duration;

  /// The route line, start to end.
  final List<LatLng> points;
  final List<MapelevenStep> steps;

  LatLngBounds get bounds {
    var s = points.first.latitude, n = s, w = points.first.longitude, e = w;
    for (final p in points) {
      if (p.latitude < s) s = p.latitude;
      if (p.latitude > n) n = p.latitude;
      if (p.longitude < w) w = p.longitude;
      if (p.longitude > e) e = p.longitude;
    }
    return LatLngBounds(southwest: LatLng(s, w), northeast: LatLng(n, e));
  }

  /// The line as a GeoJSON FeatureCollection, for [MapelevenController.addGeoJson].
  Map<String, dynamic> toGeoJson() => {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'properties': {'distance': distanceMeters, 'duration': duration.inSeconds, 'mode': mode.name},
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                for (final p in points) [p.longitude, p.latitude],
              ],
            },
          },
        ],
      };
}

/// Road routing with the provider's routing service (Valhalla).
///
/// ```dart
/// final router = MapelevenRouter(provider);
/// final routes = await router.route([from, to], mode: MapelevenTravelMode.car);
/// await controller.showRoute(routes.first);
/// ```
class MapelevenRouter {
  MapelevenRouter(this.provider, {http.Client? client}) : _client = client ?? http.Client();

  final MapelevenProvider provider;
  final http.Client _client;

  bool get available => provider.routingUrl != null;

  /// Routes through [stops] in order (at least two). Returns the best route
  /// first, then up to [alternatives] other choices when the road network has
  /// them (alternatives work between two stops only).
  Future<List<MapelevenRoute>> route(
    List<LatLng> stops, {
    MapelevenTravelMode mode = MapelevenTravelMode.car,
    MapelevenLanguage language = MapelevenLanguage.ar,
    int alternatives = 0,
  }) async {
    if (stops.length < 2) throw ArgumentError('A route needs at least two stops');
    final base = provider.routingUrl;
    if (base == null) throw StateError('Provider "${provider.id}" has no routing service');
    final request = {
      'locations': [
        for (final s in stops) {'lat': s.latitude, 'lon': s.longitude},
      ],
      'costing': mode.costing,
      'units': 'kilometers',
      'language': 'en-US',
      if (alternatives > 0 && stops.length == 2) 'alternates': alternatives,
    };
    final uri = Uri.parse('$base/route').replace(queryParameters: {
      'json': jsonEncode(request),
      if (provider.key != null) 'key': provider.key!,
    });
    final res = await _client.get(uri);
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      // Valhalla error 442 means no road connects the stops.
      final reason = body['error'] ?? body['message'];
      throw MapelevenRoutingException(
        'Routing failed: HTTP ${res.statusCode}${reason == null ? '' : ': $reason'}',
        noRoute: body['error_code'] == 442 || body['error_code'] == 171,
      );
    }
    final trips = [
      body['trip'] as Map<String, dynamic>,
      for (final alt in (body['alternates'] as List?) ?? const []) (alt as Map<String, dynamic>)['trip'] as Map<String, dynamic>,
    ];
    return [for (final t in trips) _toRoute(t, mode, language)];
  }

  void close() => _client.close();
}

/// Thrown by [MapelevenRouter.route].
class MapelevenRoutingException implements Exception {
  const MapelevenRoutingException(this.message, {this.noRoute = false});
  final String message;

  /// True when no road connects the stops (an island, a closed area).
  final bool noRoute;

  @override
  String toString() => message;
}

MapelevenRoute _toRoute(Map<String, dynamic> trip, MapelevenTravelMode mode, MapelevenLanguage language) {
  final points = <LatLng>[];
  final steps = <MapelevenStep>[];
  for (final leg in (trip['legs'] as List).cast<Map<String, dynamic>>()) {
    final shape = decodePolyline6(leg['shape'] as String);
    // Each leg starts where the previous one ended; keep that point once.
    final start = points.isEmpty ? 0 : points.length - 1;
    if (points.isNotEmpty) shape.removeAt(0);
    points.addAll(shape);
    for (final m in (leg['maneuvers'] as List).cast<Map<String, dynamic>>()) {
      final type = (m['type'] as num).toInt();
      final maneuver = _maneuver(type);
      final names = [...((m['street_names'] as List?) ?? const []).cast<String>()];
      final exit = (m['roundabout_exit_count'] as num?)?.toInt();
      final index = start + (m['begin_shape_index'] as num).toInt();
      steps.add(MapelevenStep(
        maneuver: maneuver,
        instruction: language == MapelevenLanguage.en
            ? (m['instruction'] as String? ?? '')
            : _arabic(maneuver, names, exit, mode),
        distanceMeters: (m['length'] as num).toDouble() * 1000,
        duration: Duration(milliseconds: ((m['time'] as num).toDouble() * 1000).round()),
        position: points[index.clamp(0, points.length - 1)],
        streetNames: names,
        roundaboutExit: exit,
      ));
    }
  }
  // Intermediate "arrive" steps of multi-stop routes stay; they mark each stop.
  final summary = trip['summary'] as Map<String, dynamic>;
  return MapelevenRoute(
    mode: mode,
    distanceMeters: (summary['length'] as num).toDouble() * 1000,
    duration: Duration(seconds: (summary['time'] as num).round()),
    points: points,
    steps: steps,
  );
}

MapelevenManeuver _maneuver(int t) => switch (t) {
      1 || 2 || 3 => MapelevenManeuver.start,
      4 || 5 || 6 => MapelevenManeuver.arrive,
      7 || 8 || 17 || 22 => MapelevenManeuver.continueStraight,
      9 => MapelevenManeuver.slightRight,
      10 => MapelevenManeuver.right,
      11 => MapelevenManeuver.sharpRight,
      12 || 13 => MapelevenManeuver.uTurn,
      14 => MapelevenManeuver.sharpLeft,
      15 => MapelevenManeuver.left,
      16 => MapelevenManeuver.slightLeft,
      18 => MapelevenManeuver.rampRight,
      19 => MapelevenManeuver.rampLeft,
      20 => MapelevenManeuver.exitRight,
      21 => MapelevenManeuver.exitLeft,
      23 => MapelevenManeuver.keepRight,
      24 => MapelevenManeuver.keepLeft,
      25 || 37 || 38 => MapelevenManeuver.merge,
      26 || 27 => MapelevenManeuver.roundabout,
      28 || 29 => MapelevenManeuver.ferry,
      _ => MapelevenManeuver.other,
    };

const _ordinalsAr = ['الأول', 'الثاني', 'الثالث', 'الرابع', 'الخامس', 'السادس', 'السابع', 'الثامن'];

/// Arabic instruction text (Valhalla has no Arabic narrative).
String _arabic(MapelevenManeuver m, List<String> names, int? exit, MapelevenTravelMode mode) {
  final onto = names.isEmpty ? '' : ' إلى ${names.first}';
  final along = names.isEmpty ? '' : ' على ${names.first}';
  final go = switch (mode) {
    MapelevenTravelMode.car => 'انطلق',
    MapelevenTravelMode.walk => 'امشِ',
    MapelevenTravelMode.bike => 'انطلق',
  };
  return switch (m) {
    MapelevenManeuver.start => '$go$along',
    MapelevenManeuver.arrive => 'وصلت إلى وجهتك',
    MapelevenManeuver.continueStraight => 'تابع مباشرة$along',
    MapelevenManeuver.slightRight => 'انعطف قليلًا إلى اليمين$onto',
    MapelevenManeuver.right => 'انعطف يمينًا$onto',
    MapelevenManeuver.sharpRight => 'انعطف بحدة إلى اليمين$onto',
    MapelevenManeuver.uTurn => 'استدر للخلف$onto',
    MapelevenManeuver.sharpLeft => 'انعطف بحدة إلى اليسار$onto',
    MapelevenManeuver.left => 'انعطف يسارًا$onto',
    MapelevenManeuver.slightLeft => 'انعطف قليلًا إلى اليسار$onto',
    MapelevenManeuver.rampRight => 'اسلك المنحدر على اليمين$onto',
    MapelevenManeuver.rampLeft => 'اسلك المنحدر على اليسار$onto',
    MapelevenManeuver.exitRight => 'اسلك المخرج على اليمين$onto',
    MapelevenManeuver.exitLeft => 'اسلك المخرج على اليسار$onto',
    MapelevenManeuver.keepRight => 'ابقَ على اليمين$along',
    MapelevenManeuver.keepLeft => 'ابقَ على اليسار$along',
    MapelevenManeuver.merge => 'اندمج في الطريق$onto',
    MapelevenManeuver.roundabout => exit != null && exit >= 1 && exit <= _ordinalsAr.length
        ? 'عند الدوار، اسلك المخرج ${_ordinalsAr[exit - 1]}$onto'
        : 'ادخل الدوار$onto',
    MapelevenManeuver.ferry => 'استقل العبّارة',
    MapelevenManeuver.other => 'تابع$along',
  };
}

/// Decodes a Valhalla shape (Google polyline format with 6-digit precision).
List<LatLng> decodePolyline6(String encoded) {
  final out = <LatLng>[];
  var index = 0, lat = 0, lng = 0;
  while (index < encoded.length) {
    for (var i = 0; i < 2; i++) {
      var shift = 0, result = 0, b = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final delta = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
      if (i == 0) {
        lat += delta;
      } else {
        lng += delta;
      }
    }
    out.add(LatLng(lat / 1e6, lng / 1e6));
  }
  return out;
}
