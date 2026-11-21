import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import 'provider.dart';

/// A named area to save for offline use.
class MapelevenOfflineArea {
  const MapelevenOfflineArea(this.name, this.bounds);

  /// Shown in lists of saved maps. Any language.
  final String name;
  final ml.LatLngBounds bounds;

  /// All of Jordan, Aqaba to the Syrian border.
  static final jordan = MapelevenOfflineArea(
    'Jordan',
    ml.LatLngBounds(southwest: const ml.LatLng(29.18, 34.88), northeast: const ml.LatLng(33.38, 39.31)),
  );
}

/// Progress of [MapelevenOffline.download].
class MapelevenOfflineProgress {
  const MapelevenOfflineProgress(this.fraction, this.bytes, this.done, this.total);

  /// 0 to 1.
  final double fraction;

  /// Bytes stored so far.
  final int bytes;

  /// Tiles and other files stored so far, and how many there are in all.
  final int done;
  final int total;
}

/// A saved offline map: one area at one detail level, in every theme and
/// language it was saved with.
class MapelevenOfflinePack {
  const MapelevenOfflinePack._(this._regions, {
    required this.id,
    required this.name,
    required this.bounds,
    required this.maxZoom,
    required this.complete,
    required this.bytes,
    required this.savedAt,
  });

  final String id;
  final String name;
  final ml.LatLngBounds bounds;

  /// Zoom the tiles go up to. 14 shows every street; 15 adds buildings and
  /// more shops and places.
  final double maxZoom;

  /// False when the download stopped before the end (the app closed, or the
  /// connection dropped). [MapelevenOffline.resume] finishes it.
  final bool complete;

  /// Size on the device.
  final int bytes;
  final DateTime? savedAt;
  final List<int> _regions;

  /// Whether [point] is inside the saved area.
  bool covers(ml.LatLng point) =>
      point.latitude >= bounds.southwest.latitude &&
      point.latitude <= bounds.northeast.latitude &&
      point.longitude >= bounds.southwest.longitude &&
      point.longitude <= bounds.northeast.longitude;
}

/// Saves map areas on the phone so the map works with no internet
/// (MapLibre offline packs). Android and iOS only: check [isSupported].
///
/// Use the same [MapelevenProvider], themes and languages as your
/// `MapelevenMap`: the map finds the saved tiles by their web address, and
/// with no connection it draws from them.
///
/// Search and directions still need the internet.
abstract final class MapelevenOffline {
  static const _tag = 'mapeleven';

  /// True on Android and iOS.
  static bool get isSupported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// Roughly how many map tiles [bounds] needs from zoom 0 to [maxZoom].
  /// The download also stores the style, icons and fonts.
  static int tileCount(ml.LatLngBounds bounds, double maxZoom) {
    var n = 0;
    for (var z = 0; z <= maxZoom.floor(); z++) {
      final (x0, y0) = _tile(ml.LatLng(bounds.northeast.latitude, bounds.southwest.longitude), z);
      final (x1, y1) = _tile(ml.LatLng(bounds.southwest.latitude, bounds.northeast.longitude), z);
      n += (x1 - x0 + 1) * (y1 - y0 + 1);
    }
    return n;
  }

  /// Downloads [area] for use without a connection, and returns the pack once
  /// every tile is stored.
  ///
  /// The map tiles are stored once. Each extra theme or language adds only
  /// its style, icons and fonts, about 1 MB. [maxZoom] 14 shows every street
  /// (all of Jordan is about 100 MB); 15 adds buildings and more places and
  /// roughly doubles the size, so keep it for a city.
  ///
  /// On a server that checks API keys, each tile counts towards the monthly
  /// allowance like a tile seen on the map.
  static Future<MapelevenOfflinePack> download(
    MapelevenProvider provider,
    MapelevenOfflineArea area, {
    double maxZoom = 14,
    List<MapelevenTheme> themes = const [MapelevenTheme.light],
    List<MapelevenLanguage> languages = MapelevenLanguage.values,
    void Function(MapelevenOfflineProgress progress)? onProgress,
  }) async {
    _check();
    assert(themes.isNotEmpty && languages.isNotEmpty);
    final id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final styles = [
      for (final t in themes)
        for (final l in languages) provider.styleUrl(t, l),
    ];
    final meta = {
      _tag: 1,
      'pack': id,
      'name': area.name,
      'savedAt': DateTime.now().toIso8601String(),
    };
    // MapLibre's default cap (6,000 tiles on iOS) is far below a country.
    await ml.setOfflineTileCountLimit(math.max(200000, tileCount(area.bounds, maxZoom) * 2));

    // First style: every tile in the area.
    await _run(
      ml.OfflineRegionDefinition(bounds: area.bounds, mapStyleUrl: styles.first, minZoom: 0, maxZoom: maxZoom),
      {...meta, 'role': 'tiles'},
      onProgress,
    );
    // Other themes and languages use the same tiles: fetch their style, icons
    // and fonts with a one-tile region in the middle of the area.
    final b = area.bounds;
    final c = ml.LatLng(
        (b.southwest.latitude + b.northeast.latitude) / 2, (b.southwest.longitude + b.northeast.longitude) / 2);
    final dot = ml.LatLngBounds(
      southwest: ml.LatLng(c.latitude - 0.001, c.longitude - 0.001),
      northeast: ml.LatLng(c.latitude + 0.001, c.longitude + 0.001),
    );
    for (final style in styles.skip(1)) {
      await _run(
        ml.OfflineRegionDefinition(bounds: dot, mapStyleUrl: style, minZoom: 0, maxZoom: 0),
        {...meta, 'role': 'style'},
        null,
      );
    }
    final pack = (await packs()).where((p) => p.id == id).firstOrNull;
    if (pack == null) throw StateError('The offline map was saved but could not be read back.');
    return pack;
  }

  /// Saved packs, newest first.
  static Future<List<MapelevenOfflinePack>> packs() async {
    if (!isSupported) return const [];
    final regions = await ml.getListOfRegions();
    final byPack = <String, List<ml.OfflineRegion>>{};
    for (final r in regions) {
      final pack = r.metadata['pack'];
      if (r.metadata[_tag] == null || pack is! String) continue;
      (byPack[pack] ??= []).add(r);
    }
    final out = <MapelevenOfflinePack>[];
    for (final MapEntry(key: id, value: rs) in byPack.entries) {
      final main = rs.where((r) => r.metadata['role'] == 'tiles').firstOrNull;
      if (main == null) continue;
      var bytes = 0;
      var complete = true;
      for (final r in rs) {
        final s = await ml.getOfflineRegionStatus(r.id);
        bytes += s.completedResourceSize;
        complete &= s.isComplete;
      }
      out.add(MapelevenOfflinePack._(
        [for (final r in rs) r.id],
        id: id,
        name: '${main.metadata['name'] ?? ''}',
        bounds: main.definition.bounds,
        maxZoom: main.definition.maxZoom,
        complete: complete,
        bytes: bytes,
        savedAt: DateTime.tryParse('${main.metadata['savedAt']}'),
      ));
    }
    out.sort((a, b) => (b.savedAt ?? DateTime(0)).compareTo(a.savedAt ?? DateTime(0)));
    return out;
  }

  /// Continues a pack whose download stopped, and returns once it is
  /// complete or failed again.
  static Future<void> resume(MapelevenOfflinePack pack, {void Function(MapelevenOfflineProgress)? onProgress}) async {
    _check();
    for (final id in pack._regions) {
      if ((await ml.getOfflineRegionStatus(id)).isComplete) continue;
      await ml.resumeOfflineRegionDownload(id);
      while (true) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
        final s = await ml.getOfflineRegionStatus(id);
        onProgress?.call(_progress(s.completedResourceCount, s.requiredResourceCount, s.completedResourceSize));
        if (s.isComplete) break;
      }
    }
  }

  /// Deletes a pack and frees its space. Tiles another pack also holds stay.
  static Future<void> delete(MapelevenOfflinePack pack) async {
    _check();
    for (final id in pack._regions) {
      await ml.deleteOfflineRegion(id);
    }
  }

  static Future<void> _run(
    ml.OfflineRegionDefinition definition,
    Map<String, dynamic> metadata,
    void Function(MapelevenOfflineProgress)? onProgress,
  ) {
    final done = Completer<void>();
    ml.downloadOfflineRegion(
      definition,
      metadata: metadata,
      onEvent: (e) {
        if (done.isCompleted) return;
        if (e is ml.InProgress) {
          onProgress?.call(_progress(e.completedResourceCount, e.requiredResourceCount, e.completedResourceSize));
        } else if (e is ml.Success) {
          done.complete();
        } else if (e is ml.Error) {
          done.completeError(e.cause);
        }
      },
    ).catchError((Object e) {
      if (!done.isCompleted) done.completeError(e);
      return ml.OfflineRegion(id: -1, definition: definition, metadata: metadata);
    });
    return done.future;
  }

  // From counts: the platforms disagree on the scale of their own progress figure.
  static MapelevenOfflineProgress _progress(int done, int total, int bytes) =>
      MapelevenOfflineProgress(total > 0 ? (done / total).clamp(0, 1).toDouble() : 0, bytes, done, total);

  static void _check() {
    if (!isSupported) throw UnsupportedError('Offline maps need Android or iOS.');
  }

  static (int, int) _tile(ml.LatLng p, int z) {
    final n = 1 << z;
    final x = ((p.longitude + 180) / 360 * n).floor().clamp(0, n - 1);
    final lat = p.latitude.clamp(-85.05, 85.05) * math.pi / 180;
    final y = ((1 - math.log(math.tan(lat) + 1 / math.cos(lat)) / math.pi) / 2 * n).floor().clamp(0, n - 1);
    return (x, y);
  }
}
