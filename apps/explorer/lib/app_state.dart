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

/// A GPS answer that does not fit where the user was: jammed or faked GPS
/// often puts a phone tens or hundreds of kilometres away in an instant.
class GpsDoubt {
  const GpsDoubt({required this.position, required this.km, required this.since, this.mocked = false, this.handName});

  /// Where GPS says the user is.
  final LatLng position;

  /// How far that is from the last trusted position.
  final double km;

  /// Time since the last trusted position.
  final Duration since;

  /// The phone reports the location comes from an app (Android only).
  final bool mocked;

  /// Set when the comparison is with a position the user set by hand.
  final String? handName;
}

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

  /// Map types offered in the app. The SDK has more; two keep the choice simple.
  static const themes = [MapelevenTheme.light, MapelevenTheme.dark];

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

  /// A position set by hand (tapping a landmark the user can see), for when
  /// GPS is off, jammed or wrong. It wins over GPS until cleared or until the
  /// user asks GPS again and it answers.
  SavedPlace? manualHere;
  DateTime? manualHereAt;

  /// Last GPS position the app trusted, kept across restarts for [checkFix].
  LatLng? _lastFix;
  DateTime? _lastFixAt;

  /// A GPS answer waiting for the user to accept or reject it.
  GpsDoubt? doubt;

  /// The user said GPS is wrong: hide the GPS dot until a fix is accepted.
  bool gpsDistrusted = false;

  /// Where distances and directions start: the hand-set position, else GPS.
  LatLng? get here => manualHere?.position ?? myLocation;
  SharedPreferences? _prefs;

  Future<void> load() async {
    try {
      final p = _prefs = await SharedPreferences.getInstance();
      language = MapelevenLanguage.values.asNameMap()[p.getString('language')] ?? language;
      final savedTheme = MapelevenTheme.values.asNameMap()[p.getString('theme')];
      if (themes.contains(savedTheme)) theme = savedTheme!;
      satellite = imagery != null && (p.getBool('satellite') ?? false);
      saved.addAll(_decode(p.getString('saved')));
      recent.addAll(_decode(p.getString('recent')));
      final fix = p.getString('lastFix');
      if (fix != null) {
        final j = jsonDecode(fix) as Map<String, dynamic>;
        _lastFix = LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble());
        _lastFixAt = DateTime.tryParse(j['at'] as String? ?? '');
      }
      final manual = p.getString('manualHere');
      if (manual != null) {
        final j = jsonDecode(manual) as Map<String, dynamic>;
        manualHere = SavedPlace.fromJson(j['place'] as Map<String, dynamic>);
        manualHereAt = DateTime.tryParse(j['at'] as String? ?? '');
      }
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

  void setManualHere(SavedPlace place) {
    manualHere = place;
    manualHereAt = DateTime.now();
    myLocation = null;
    _prefs?.setString('manualHere', jsonEncode({'place': place, 'at': manualHereAt!.toIso8601String()}));
    notifyListeners();
  }

  void clearManualHere() {
    manualHere = null;
    manualHereAt = null;
    _prefs?.remove('manualHere');
    notifyListeners();
  }

  /// Checks a GPS answer against the last trusted position. Returns why it
  /// looks wrong, or null when it is believable.
  GpsDoubt? checkFix(LatLng p, {bool mocked = false}) {
    final now = DateTime.now();
    final manual = manualHere;
    if (manual != null) {
      // The user set a position because GPS was off or wrong: ask before GPS overrides it.
      final km = distanceKm(manual.position, p);
      if (mocked || km > 5) {
        return GpsDoubt(position: p, km: km, since: now.difference(manualHereAt ?? now), mocked: mocked, handName: manual.name);
      }
      return null;
    }
    final ref = _lastFix, at = _lastFixAt;
    if (ref == null || at == null) return mocked ? GpsDoubt(position: p, km: 0, since: Duration.zero, mocked: true) : null;
    final km = distanceKm(ref, p);
    final since = now.difference(at);
    final hours = math.max(since.inSeconds / 3600, 1 / 60);
    // Faster than 250 km/h over more than 3 km is not a car trip.
    if (mocked || (km > 3 && km / hours > 250)) return GpsDoubt(position: p, km: km, since: since, mocked: mocked);
    return null;
  }

  /// Remembers a GPS position as trusted.
  void recordFix(LatLng p) {
    _lastFix = p;
    _lastFixAt = DateTime.now();
    _prefs?.setString('lastFix', jsonEncode({'lat': p.latitude, 'lng': p.longitude, 'at': _lastFixAt!.toIso8601String()}));
  }

  /// Uses the doubted GPS answer anyway.
  LatLng? acceptDoubt() {
    final d = doubt;
    if (d == null) return null;
    doubt = null;
    gpsDistrusted = false;
    myLocation = d.position;
    recordFix(d.position);
    if (manualHere != null) clearManualHere();
    notifyListeners();
    return d.position;
  }

  /// Ignores the doubted GPS answer and hides the GPS dot.
  void rejectDoubt() {
    doubt = null;
    gpsDistrusted = true;
    myLocation = null;
    notifyListeners();
  }

  /// Asks for permission if needed and returns the current position, or null.
  /// A position that does not fit where the user was is not used: it is put
  /// in [doubt] for the user to decide, and null is returned.
  Future<LatLng?> locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
      );
      final p = LatLng(pos.latitude, pos.longitude);
      final d = checkFix(p, mocked: pos.isMocked);
      if (d != null) {
        doubt = d;
        notifyListeners();
        return null;
      }
      doubt = null;
      gpsDistrusted = false;
      myLocation = p;
      recordFix(p);
      if (manualHere != null) clearManualHere();
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
