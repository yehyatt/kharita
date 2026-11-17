import 'dart:convert';

import 'provider.dart';

/// Expression that picks the label in [language], falling back to the local name.
List<Object> nameExpression(MapelevenLanguage language) => language == MapelevenLanguage.en
    ? [
        'coalesce',
        ['get', 'name:en'],
        ['get', 'name_en'],
        ['get', 'name:latin'],
        ['get', 'name'],
      ]
    : [
        'coalesce',
        ['get', 'name:${language.name}'],
        ['get', 'name'],
      ];

final _nameRef = RegExp(r'"name[:_"]');

/// Rewrites the name labels of an OpenMapTiles-schema style to one language.
/// House numbers and road refs are left alone.
Map<String, dynamic> localizeStyle(Map<String, dynamic> style, MapelevenLanguage language) {
  final expr = nameExpression(language);
  final layers = (style['layers'] as List).map((raw) {
    final layer = raw as Map<String, dynamic>;
    final layout = layer['layout'] as Map<String, dynamic>?;
    final field = layout?['text-field'];
    if (layer['type'] != 'symbol' || field == null || !_nameRef.hasMatch(jsonEncode(field))) {
      return layer;
    }
    return {
      ...layer,
      'layout': {...layout!, 'text-field': expr},
    };
  }).toList();
  return {...style, 'layers': layers};
}
