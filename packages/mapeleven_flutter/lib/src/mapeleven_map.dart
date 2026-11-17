import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';

import 'mapeleven_controller.dart';
import 'localize.dart';
import 'provider.dart';
import 'rtl_stub.dart' if (dart.library.js_interop) 'rtl_web.dart';

/// A map with sensible defaults: labels in the app's language (Arabic or
/// English), OSM attribution, theme and language switching. Change [language] or [theme] and rebuild; markers and
/// layers added through the controller are kept.
class MapelevenMap extends StatefulWidget {
  const MapelevenMap({
    super.key,
    this.provider,
    this.language,
    this.theme = MapelevenTheme.light,
    this.initialCenter = const LatLng(31.9539, 35.9106),
    this.initialZoom = 11,
    this.showUserLocation = false,
    this.onMapReady,
    this.onTap,
    this.onLongPress,
    this.onPoiTap,
    this.onCameraIdle,
    this.compassEnabled = true,
  });

  /// Defaults to [MapelevenProvider.openFreeMap] (development use).
  final MapelevenProvider? provider;
  /// Label language. Leave it null to follow the app's locale (from
  /// `MaterialApp`, else the device): Arabic for Arabic, English otherwise.
  final MapelevenLanguage? language;
  final MapelevenTheme theme;
  final LatLng initialCenter;
  final double initialZoom;

  /// Shows the blue location dot. Your app must hold location permission first
  /// (for example with the `permission_handler` or `geolocator` package).
  final bool showUserLocation;

  /// Called once, when the first style has loaded.
  final void Function(MapelevenController controller)? onMapReady;
  final void Function(LatLng position)? onTap;
  final void Function(LatLng position)? onLongPress;

  /// Called when the user taps a shop, café, mosque or other basemap place.
  /// Taps that miss a place still go to [onTap].
  final void Function(MapelevenPoi poi)? onPoiTap;

  /// Called when the camera stops moving, with the map centre and zoom. Use it
  /// for a fixed-centre pin picker: reverse geocode [center] here.
  final void Function(LatLng center, double zoom)? onCameraIdle;

  /// Shows the compass after the user rotates the map.
  final bool compassEnabled;

  @override
  State<MapelevenMap> createState() => _MapelevenMapState();
}

class _MapelevenMapState extends State<MapelevenMap> {
  static final Map<String, Map<String, dynamic>> _styleCache = {};

  late final MapelevenProvider _provider = widget.provider ?? MapelevenProvider.openFreeMap();
  MapelevenController? _controller;
  String? _style;
  Object? _error;
  bool _announced = false;
  int _request = 0;
  MapelevenLanguage? _language;

  MapelevenLanguage get language => _language!;

  MapelevenLanguage _pickLanguage() =>
      widget.language ??
      MapelevenLanguage.fromLocale(Localizations.maybeLocaleOf(context) ?? WidgetsBinding.instance.platformDispatcher.locale);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _update(theme: widget.theme);
  }

  @override
  void didUpdateWidget(MapelevenMap old) {
    super.didUpdateWidget(old);
    _update(theme: old.theme);
  }

  /// Reloads the style when the language (widget or app locale) or theme changed.
  void _update({required MapelevenTheme theme}) {
    final next = _pickLanguage();
    final first = _language == null;
    if (!first && next == _language && theme == widget.theme) return;
    _language = next;
    _controller?.language = next;
    if (!first) _controller?.onStyleChanging();
    _resolveStyle();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _resolveStyle() async {
    final request = ++_request;
    final url = _provider.styleUrl(widget.theme, language);
    try {
      String style = url;
      if (_provider.localizeOnClient) {
        final base = _styleCache[url] ??= await _fetchJson(url);
        style = jsonEncode(localizeStyle(base, language));
      }
      if (mounted && request == _request) {
        setState(() {
          _style = style;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && request == _request) setState(() => _error = e);
    }
  }

  static Future<Map<String, dynamic>> _fetchJson(String url) async {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw http.ClientException('Style failed to load: HTTP ${res.statusCode}', Uri.parse(url));
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    if (style == null) {
      return ColoredBox(
        color: widget.theme == MapelevenTheme.light || widget.theme == MapelevenTheme.white
            ? const Color(0xFFF2EFE9)
            : const Color(0xFF1E293B),
        child: Center(
          child: _error == null ? const CircularProgressIndicator() : Text('$_error', textAlign: TextAlign.center),
        ),
      );
    }
    final rtl = language == MapelevenLanguage.ar;
    return MapLibreMap(
      styleString: style,
      initialCameraPosition: CameraPosition(target: widget.initialCenter, zoom: widget.initialZoom),
      onMapCreated: (raw) {
        ensureRtlPlugin(_provider.rtlPluginUrl);
        _controller = MapelevenController.internal(raw, _provider, language: language);
      },
      onStyleLoadedCallback: () async {
        final controller = _controller;
        if (controller == null) return;
        await controller.onStyleLoaded();
        if (!_announced) {
          _announced = true;
          widget.onMapReady?.call(controller);
        }
      },
      myLocationEnabled: widget.showUserLocation,
      onMapClick: (point, latLng) async {
        final poi = widget.onPoiTap == null ? null : await _controller?.poiAt(point);
        if (poi != null) {
          widget.onPoiTap!(poi);
        } else {
          widget.onTap?.call(latLng);
        }
      },
      onCameraIdle: () {
        final camera = _controller?.raw.cameraPosition;
        if (camera != null) widget.onCameraIdle?.call(camera.target, camera.zoom);
      },
      compassEnabled: widget.compassEnabled,
      onMapLongClick: (_, latLng) => widget.onLongPress?.call(latLng),
      // OSM's licence (ODbL) requires visible attribution; Mapeleven keeps the button on.
      attributionButtonPosition: rtl ? AttributionButtonPosition.bottomLeft : AttributionButtonPosition.bottomRight,
      compassViewPosition: rtl ? CompassViewPosition.bottomRight : CompassViewPosition.bottomLeft,
      trackCameraPosition: true,
    );
  }
}
