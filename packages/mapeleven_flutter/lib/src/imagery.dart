/// Satellite or aerial imagery drawn under the map's roads and labels.
///
/// Imagery comes straight from the provider you pick, with your own key from
/// that provider; Mapeleven does not proxy or pay for it. Pass it to
/// `MapelevenMap(imagery: ...)`. Each provider's terms and attribution apply,
/// and the attribution is added to the map for you.
class MapelevenImagery {
  const MapelevenImagery.custom({
    required this.tiles,
    required this.attribution,
    this.tileSize = 256,
    this.maxZoom = 19,
    this.tileJsonUrl,
  });

  /// Esri World Imagery. Needs an ArcGIS Location Platform API key with the
  /// basemap privilege (developers.arcgis.com). Esri's free tier covers
  /// 2 million tiles a month at the time of writing.
  factory MapelevenImagery.esri(String apiKey) => MapelevenImagery.custom(
        tiles: [
          'https://ibasemaps-api.arcgis.com/arcgis/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
              '?token=${Uri.encodeQueryComponent(apiKey)}',
        ],
        attribution: 'Imagery: Esri, Maxar, Earthstar Geographics, and the GIS User Community',
        maxZoom: 19,
      );

  /// MapTiler Satellite. Needs a MapTiler Cloud key (maptiler.com). The free
  /// MapTiler plan is for non-commercial use; live commercial apps need a
  /// paid plan.
  factory MapelevenImagery.mapTiler(String apiKey) => MapelevenImagery.custom(
        tiles: const [],
        tileJsonUrl: 'https://api.maptiler.com/tiles/satellite-v4/tiles.json?key=${Uri.encodeQueryComponent(apiKey)}',
        attribution: '<a href="https://www.maptiler.com/copyright/">© MapTiler</a>',
        tileSize: 512,
        maxZoom: 20,
      );

  /// XYZ tile URL templates (`{z}`, `{x}`, `{y}`). Ignored when [tileJsonUrl] is set.
  final List<String> tiles;

  /// TileJSON URL describing the tiles, used instead of [tiles] when set.
  final String? tileJsonUrl;

  /// Credit shown in the map's attribution, as the provider requires.
  final String attribution;
  final int tileSize;
  final int maxZoom;

  @override
  bool operator ==(Object other) =>
      other is MapelevenImagery && other.tileJsonUrl == tileJsonUrl && other.tiles.join('|') == tiles.join('|');

  @override
  int get hashCode => Object.hash(tileJsonUrl, tiles.join('|'));

  /// The style source for this imagery.
  Map<String, dynamic> toSource() => {
        'type': 'raster',
        if (tileJsonUrl != null) 'url': tileJsonUrl else 'tiles': tiles,
        'tileSize': tileSize,
        'maxzoom': maxZoom,
        'attribution': attribution,
      };
}

/// Source and layer ids the SDK uses for imagery.
const imagerySourceId = 'imagery';

/// Turns a vector style into a hybrid map: imagery at the bottom, then the
/// style's roads, borders and labels, recoloured to read over photos (white
/// text on a dark halo, light semi-transparent roads). Fills, casings, water
/// and the background are dropped so the imagery shows through.
Map<String, dynamic> hybridStyle(Map<String, dynamic> style, MapelevenImagery imagery) {
  final kept = <Map<String, dynamic>>[];
  for (final raw in style['layers'] as List) {
    final layer = Map<String, dynamic>.from(raw as Map);
    final id = '${layer['id']}';
    final paint = Map<String, dynamic>.from((layer['paint'] as Map?) ?? const {});
    final layout = (layer['layout'] as Map?) ?? const {};
    if (layer['type'] == 'symbol') {
      if (layout.containsKey('text-field') && id != 'roads_shields') {
        paint['text-color'] = '#ffffff';
        paint['text-halo-color'] = 'rgba(0,0,0,0.8)';
        paint['text-halo-width'] = 1.4;
      }
    } else if (layer['type'] == 'line' && id.startsWith('boundaries')) {
      paint['line-color'] = '#ffffff';
      paint['line-opacity'] = 0.7;
    } else if (layer['type'] == 'line' && id.startsWith('roads_') && !_hiddenRoad.hasMatch(id)) {
      final major = id.contains('highway') || id.contains('major');
      paint['line-color'] = id.contains('highway') ? '#ffd166' : '#ffffff';
      paint['line-opacity'] = major ? 0.7 : 0.4;
    } else {
      continue;
    }
    layer['paint'] = paint;
    kept.add(layer);
  }
  return {
    ...style,
    'sources': {
      ...(style['sources'] as Map).cast<String, dynamic>(),
      imagerySourceId: imagery.toSource(),
    },
    'layers': [
      {'id': 'imagery-background', 'type': 'background', 'paint': {'background-color': '#0b1a12'}},
      {'id': imagerySourceId, 'type': 'raster', 'source': imagerySourceId},
      ...kept,
    ],
  };
}

final _hiddenRoad = RegExp('casing|runway|taxiway|pier|rail');
