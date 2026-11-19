import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapeleven/mapeleven.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Map server used by the demo. Override with
/// `--dart-define=MAPELEVEN_SERVER=https://your.server`.
const serverUrl = String.fromEnvironment('MAPELEVEN_SERVER', defaultValue: 'https://mapeleven.dev');
final provider = MapelevenProvider.selfHosted(serverUrl);

/// Amman, where the demo opens.
const amman = LatLng(31.9539, 35.9106);

/// A place the user saved or searched for, stored as JSON.
class SavedPlace {
  const SavedPlace({required this.name, required this.address, required this.position, this.kind});

  final String name;
  final String address;
  final LatLng position;
  final String? kind;

  String get key => '${position.latitude.toStringAsFixed(5)},${position.longitude.toStringAsFixed(5)}';

  Map<String, dynamic> toJson() => {
    'name': name,
    'address': address,
    'lat': position.latitude,
    'lng': position.longitude,
    'kind': kind,
  };

  factory SavedPlace.fromJson(Map<String, dynamic> j) => SavedPlace(
    name: j['name'] as String,
    address: j['address'] as String? ?? '',
    position: LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
    kind: j['kind'] as String?,
  );

  factory SavedPlace.fromPlace(MapelevenPlace p) =>
      SavedPlace(name: p.name, address: p.address, position: p.position, kind: p.type);
}

/// Language, theme, saved places and recent searches, persisted on the device.
class AppState extends ChangeNotifier {
  MapelevenLanguage language = MapelevenLanguage.ar;
  MapelevenTheme theme = MapelevenTheme.light;

  /// Satellite imagery, when the build was given a key:
  /// `--dart-define=ESRI_KEY=...` or `--dart-define=MAPTILER_KEY=...`.
  /// Public builds have none, so the satellite option stays hidden.
  static final MapelevenImagery? imagery = switch ((
    const String.fromEnvironment('ESRI_KEY'),
    const String.fromEnvironment('MAPTILER_KEY'),
    const String.fromEnvironment('IMAGERY_TILES'),
  )) {
    (final esri, _, _) when esri.isNotEmpty => MapelevenImagery.esri(esri),
    (_, final mt, _) when mt.isNotEmpty => MapelevenImagery.mapTiler(mt),
    (_, _, final tiles) when tiles.isNotEmpty =>
      MapelevenImagery.custom(tiles: [tiles], attribution: const String.fromEnvironment('IMAGERY_CREDIT', defaultValue: 'Imagery')),
    _ => null,
  };

  bool satellite = false;

  /// Imagery to pass to the map: null unless satellite is on.
  MapelevenImagery? get activeImagery => satellite ? imagery : null;

  void setSatellite(bool on) {
    satellite = on;
    _prefs?.setBool('satellite', on);
    notifyListeners();
  }
  final List<SavedPlace> saved = [];
  final List<SavedPlace> recent = [];
  LatLng? myLocation;
  SharedPreferences? _prefs;

  Future<void> load() async {
    try {
      final p = _prefs = await SharedPreferences.getInstance();
      language = MapelevenLanguage.values.asNameMap()[p.getString('language')] ?? language;
      theme = MapelevenTheme.values.asNameMap()[p.getString('theme')] ?? theme;
      satellite = imagery != null && (p.getBool('satellite') ?? false);
      saved.addAll(_decode(p.getString('saved')));
      recent.addAll(_decode(p.getString('recent')));
    } catch (_) {
      // Storage unavailable (private browsing): run with defaults.
    }
  }

  void setLanguage(MapelevenLanguage l) {
    language = l;
    _prefs?.setString('language', l.name);
    notifyListeners();
  }

  void setTheme(MapelevenTheme t) {
    theme = t;
    _prefs?.setString('theme', t.name);
    notifyListeners();
  }

  bool isSaved(SavedPlace p) => saved.any((s) => s.key == p.key);

  void toggleSaved(SavedPlace p) {
    final i = saved.indexWhere((s) => s.key == p.key);
    i >= 0 ? saved.removeAt(i) : saved.insert(0, p);
    _prefs?.setString('saved', jsonEncode(saved));
    notifyListeners();
  }

  void addRecent(SavedPlace p) {
    recent.removeWhere((s) => s.key == p.key);
    recent.insert(0, p);
    if (recent.length > 8) recent.removeLast();
    _prefs?.setString('recent', jsonEncode(recent));
  }

  /// Asks for permission if needed and returns the current position, or null.
  Future<LatLng?> locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
      );
      myLocation = LatLng(pos.latitude, pos.longitude);
      notifyListeners();
      return myLocation;
    } catch (_) {
      return null;
    }
  }

  static List<SavedPlace> _decode(String? raw) {
    if (raw == null) return const [];
    return (jsonDecode(raw) as List).map((e) => SavedPlace.fromJson(e as Map<String, dynamic>)).toList();
  }
}

/// Great-circle distance in kilometres.
double distanceKm(LatLng a, LatLng b) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.latitude - a.latitude);
  final dLng = rad(b.longitude - a.longitude);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.latitude)) * math.cos(rad(b.latitude)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(h));
}

/// Compass bearing from [a] to [b], in degrees clockwise from north.
double bearing(LatLng a, LatLng b) {
  double rad(double d) => d * math.pi / 180;
  final y = math.sin(rad(b.longitude - a.longitude)) * math.cos(rad(b.latitude));
  final x =
      math.cos(rad(a.latitude)) * math.sin(rad(b.latitude)) -
      math.sin(rad(a.latitude)) * math.cos(rad(b.latitude)) * math.cos(rad(b.longitude - a.longitude));
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}
