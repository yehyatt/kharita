import 'dart:ui' show Locale;

/// Label language of the map and of search results.
enum MapelevenLanguage {
  ar,
  en;

  /// Arabic for an Arabic locale, English for every other locale.
  static MapelevenLanguage fromLocale(Locale? locale) => locale?.languageCode == 'ar' ? ar : en;
}

/// Visual theme. [light] and [dark] work on every provider; the rest only on a
/// self-hosted Mapeleven server.
enum MapelevenTheme { light, dark, white, grayscale, black }

/// Where styles, tiles and search come from. Swap providers without touching
/// map code: start on [MapelevenProvider.openFreeMap], move to
/// [MapelevenProvider.selfHosted] for production.
class MapelevenProvider {
  const MapelevenProvider({
    required this.id,
    required this.styleUrlBuilder,
    required this.localizeOnClient,
    this.searchUrl,
    this.searchLanguages = const [],
    this.fontStack = const ['Noto Sans Regular'],
    this.rtlPluginUrl = publicRtlPluginUrl,
    this.poiSource,
    this.key,
  });

  /// Public copy of the plugin that shapes Arabic text on Flutter web.
  static const publicRtlPluginUrl = 'https://unpkg.com/@mapbox/mapbox-gl-rtl-text@0.3.0/dist/mapbox-gl-rtl-text.js';

  /// Your own Mapeleven server (see server/README.md), e.g. `https://maps.example.com`.
  /// Pass [key] if the server issues API keys.
  factory MapelevenProvider.selfHosted(String baseUrl, {String? key}) {
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final query = key == null ? '' : '?key=${Uri.encodeQueryComponent(key)}';
    return MapelevenProvider(
      id: 'self-hosted',
      key: key,
      styleUrlBuilder: (theme, language) => '$base/styles/${theme.name}-${language.name}.json$query',
      localizeOnClient: false,
      searchUrl: '$base/search',
      searchLanguages: const ['ar', 'en'],
      rtlPluginUrl: '$base/assets/rtl/mapbox-gl-rtl-text.js',
      poiSource: ('protomaps', 'pois'),
    );
  }

  /// The hosted Mapeleven service at mapeleven.dev. Pass your free [key] from
  /// https://mapeleven.dev/account/ for production: it carries your monthly
  /// allowance and usage stats. Without a key it works for development, with
  /// searches limited per device.
  factory MapelevenProvider.hosted({String? key, String baseUrl = 'https://mapeleven.dev'}) =>
      MapelevenProvider.selfHosted(baseUrl, key: key);

  /// OpenFreeMap public tiles (free, no key) and the public Photon demo for
  /// search. Good for development and small apps; both are community services
  /// under fair-use terms, so use [MapelevenProvider.selfHosted] before real traffic.
  factory MapelevenProvider.openFreeMap({String searchUrl = 'https://photon.komoot.io'}) {
    return MapelevenProvider(
      id: 'openfreemap',
      styleUrlBuilder: (theme, _) => switch (theme) {
        MapelevenTheme.light => 'https://tiles.openfreemap.org/styles/liberty',
        MapelevenTheme.dark || MapelevenTheme.black => 'https://tiles.openfreemap.org/styles/dark',
        _ => 'https://tiles.openfreemap.org/styles/positron',
      },
      localizeOnClient: true,
      searchUrl: searchUrl,
      searchLanguages: const ['en', 'de', 'fr'],
      poiSource: ('openmaptiles', 'poi'),
    );
  }

  final String id;

  /// API key sent with style and search requests, or null.
  final String? key;

  /// Builds the style URL for a theme and language.
  final String Function(MapelevenTheme, MapelevenLanguage) styleUrlBuilder;

  /// True when the style is single-language and labels are rewritten on the client.
  final bool localizeOnClient;

  /// Photon-compatible search endpoint without trailing slash, or null.
  final String? searchUrl;

  /// Languages the search index holds; others fall back to local names.
  final List<String> searchLanguages;

  /// Font stack served by the provider's glyph server, for SDK-drawn labels.
  final List<String> fontStack;

  /// Script that shapes Arabic labels in MapLibre GL JS (Flutter web only).
  final String rtlPluginUrl;

  /// Vector source and source-layer that hold points of interest, for
  /// [MapelevenController.nearbyPois]. Null when unknown.
  final (String, String)? poiSource;

  String styleUrl(MapelevenTheme theme, MapelevenLanguage language) => styleUrlBuilder(theme, language);
}
