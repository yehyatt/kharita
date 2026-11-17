import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';

import 'provider.dart';

/// A search or reverse-geocoding result.
class MapelevenPlace {
  const MapelevenPlace({
    required this.name,
    required this.address,
    required this.position,
    this.type,
    this.city,
    this.country,
    this.countryCode,
    this.bounds,
    this.osmId,
  });

  final String name;

  /// Where it is, without the name: street, district, city, country.
  final String address;
  final LatLng position;

  /// OSM category, e.g. `city`, `restaurant`, `street`.
  final String? type;
  final String? city;
  final String? country;
  final String? countryCode;

  /// Set when the place is an area (city, district, campus).
  final LatLngBounds? bounds;
  final String? osmId;

  /// Name and address on one line.
  String label([String separator = '، ']) => address.isEmpty ? name : '$name$separator$address';
}

/// Forward and reverse geocoding against a Photon server.
class MapelevenSearch {
  MapelevenSearch(this.provider, {http.Client? client}) : _client = client ?? http.Client();

  final MapelevenProvider provider;
  final http.Client _client;

  bool get available => provider.searchUrl != null;

  Future<List<MapelevenPlace>> search(String query, {MapelevenLanguage? language, LatLng? near, int limit = 8}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    return _fetch('api', language, {
      'q': q,
      'limit': '$limit',
      if (near != null) 'lat': '${near.latitude}',
      if (near != null) 'lon': '${near.longitude}',
    });
  }

  Future<MapelevenPlace?> reverse(LatLng position, {MapelevenLanguage? language}) async {
    final places = await _fetch('reverse', language, {
      'lat': '${position.latitude}',
      'lon': '${position.longitude}',
      'limit': '1',
    });
    return places.isEmpty ? null : places.first;
  }

  Future<List<MapelevenPlace>> _fetch(String path, MapelevenLanguage? language, Map<String, String> params) async {
    final base = provider.searchUrl;
    if (base == null) throw StateError('Provider "${provider.id}" has no search service');
    // Photon only accepts languages present in its index; "default" returns local names.
    final lang = language != null && provider.searchLanguages.contains(language.name) ? language.name : 'default';
    final uri = Uri.parse('$base/$path').replace(queryParameters: {...params, 'lang': lang});
    final res = await _client.get(uri);
    if (res.statusCode != 200) throw http.ClientException('Search failed: HTTP ${res.statusCode}', uri);
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final separator = language == MapelevenLanguage.en ? ', ' : '، ';
    return (body['features'] as List).map((f) => _toPlace(f as Map<String, dynamic>, separator)).toList();
  }

  void close() => _client.close();
}

MapelevenPlace _toPlace(Map<String, dynamic> f, String separator) {
  final p = f['properties'] as Map<String, dynamic>;
  final coords = (f['geometry'] as Map<String, dynamic>)['coordinates'] as List;
  String? s(String key) => p[key]?.toString();
  final street = s('street') == null ? null : [s('street'), s('housenumber')].whereType<String>().join(' ');
  final name = s('name') ?? street ?? s('city') ?? s('country') ?? '';
  final address = [
    street != name ? street : null,
    s('district'),
    s('city') != name ? s('city') : null,
    s('country') != name ? s('country') : null,
  ].whereType<String>().join(separator);
  final extent = (p['extent'] as List?)?.cast<num>();
  return MapelevenPlace(
    name: name,
    address: address,
    position: LatLng((coords[1] as num).toDouble(), (coords[0] as num).toDouble()),
    type: s('osm_value') ?? s('type'),
    city: s('city'),
    country: s('country'),
    countryCode: s('countrycode'),
    // Photon extent is [minLon, maxLat, maxLon, minLat].
    bounds: extent == null
        ? null
        : LatLngBounds(
            southwest: LatLng(extent[3].toDouble(), extent[0].toDouble()),
            northeast: LatLng(extent[1].toDouble(), extent[2].toDouble()),
          ),
    osmId: s('osm_type') != null && s('osm_id') != null ? '${s('osm_type')}${s('osm_id')}' : null,
  );
}
