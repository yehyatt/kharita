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
    this.street,
    this.houseNumber,
    this.postcode,
    this.district,
    this.locality,
    this.county,
    this.state,
    this.properties = const {},
    this.separator = '، ',
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

  /// OSM object, e.g. `N123456` (node), `W42` (way), `R7` (relation).
  final String? osmId;

  final String? street;
  final String? houseNumber;
  final String? postcode;

  /// Neighbourhood or district (حي / منطقة) when OSM has one.
  final String? district;

  /// Locality inside a city, when OSM has one.
  final String? locality;
  final String? county;

  /// Governorate, province or emirate.
  final String? state;

  /// The raw Photon properties, for fields not mapped above.
  final Map<String, dynamic> properties;

  /// Administrative names from most to least specific, without duplicates:
  /// district, locality, city, county, state. Useful for matching delivery zones.
  List<String> get adminAreas => [district, locality, city, county, state].whereType<String>().toSet().toList();

  /// Comma used in [address]: Arabic `، ` or Latin `, `, matching the language.
  final String separator;

  /// Name and address on one line.
  String label([String? separator]) => address.isEmpty ? name : '$name${separator ?? this.separator}$address';
}

/// Forward and reverse geocoding against a Photon server.
class MapelevenSearch {
  MapelevenSearch(this.provider, {http.Client? client}) : _client = client ?? http.Client();

  final MapelevenProvider provider;
  final http.Client _client;

  bool get available => provider.searchUrl != null;

  /// Finds places matching [query]; works as you type (autocomplete).
  ///
  /// [near] ranks results close to a point first; [nearZoom] sets how local
  /// (14 is about a city, lower widens it). [bounds] keeps only results
  /// inside a box (for example one country). [osmTags] filters by category,
  /// e.g. `['amenity:pharmacy']` or `['shop']`.
  Future<List<MapelevenPlace>> search(
    String query, {
    MapelevenLanguage? language,
    LatLng? near,
    int nearZoom = 14,
    LatLngBounds? bounds,
    List<String> osmTags = const [],
    int limit = 8,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    return _fetch('api', language, {
      'q': q,
      'limit': '$limit',
      if (near != null) 'lat': '${near.latitude}',
      if (near != null) 'lon': '${near.longitude}',
      if (near != null) 'zoom': '$nearZoom',
      if (bounds != null)
        'bbox':
            '${bounds.southwest.longitude},${bounds.southwest.latitude},${bounds.northeast.longitude},${bounds.northeast.latitude}',
    }, osmTags);
  }

  Future<MapelevenPlace?> reverse(LatLng position, {MapelevenLanguage? language}) async {
    final places = await _fetch('reverse', language, {
      'lat': '${position.latitude}',
      'lon': '${position.longitude}',
      'limit': '1',
    });
    return places.isEmpty ? null : places.first;
  }

  Future<List<MapelevenPlace>> _fetch(
    String path,
    MapelevenLanguage? language,
    Map<String, String> params, [
    List<String> osmTags = const [],
  ]) async {
    final base = provider.searchUrl;
    if (base == null) throw StateError('Provider "${provider.id}" has no search service');
    // Photon only accepts languages present in its index; "default" returns local names.
    final lang = language != null && provider.searchLanguages.contains(language.name) ? language.name : 'default';
    final uri = Uri.parse(
      '$base/$path',
    ).replace(
      queryParameters: {
        ...params,
        'lang': lang,
        if (osmTags.isNotEmpty) 'osm_tag': osmTags,
        if (provider.key != null) 'key': provider.key!,
      },
    );
    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      final reason = _errorMessage(res.bodyBytes);
      throw http.ClientException('Search failed: HTTP ${res.statusCode}${reason == null ? '' : ': $reason'}', uri);
    }
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
    street: s('street'),
    houseNumber: s('housenumber'),
    postcode: s('postcode'),
    district: s('district'),
    locality: s('locality'),
    county: s('county'),
    state: s('state'),
    properties: p,
    separator: separator,
  );
}

/// The server's error message (`{"error": "..."}`), if the body has one.
String? _errorMessage(List<int> body) {
  try {
    final decoded = jsonDecode(utf8.decode(body));
    return decoded is Map && decoded['error'] is String ? decoded['error'] as String : null;
  } catch (_) {
    return null;
  }
}
