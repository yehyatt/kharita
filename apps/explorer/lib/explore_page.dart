import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapeleven/mapeleven.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart';
import 'contribute_page.dart';
import 'main.dart';
import 'search_page.dart';
import 'strings.dart';

/// Category chips: label key, icon, and the basemap kinds it covers.
const categories = <(String, IconData, Set<String>)>[
  ('restaurant', Icons.restaurant, {'restaurant', 'fast_food'}),
  ('cafe', Icons.local_cafe, {'cafe', 'coffee'}),
  ('pharmacy', Icons.local_pharmacy, {'pharmacy', 'chemist'}),
  ('hospital', Icons.local_hospital, {'hospital', 'clinic', 'doctors'}),
  ('fuel', Icons.local_gas_station, {'fuel'}),
  ('atm', Icons.atm, {'atm'}),
  ('bank', Icons.account_balance, {'bank'}),
  ('place_of_worship', Icons.mosque, {'place_of_worship'}),
  ('supermarket', Icons.shopping_cart, {'supermarket', 'convenience', 'greengrocer'}),
  ('hotel', Icons.hotel, {'hotel', 'guest_house'}),
];

/// The selected place and how it is shown.
class _Selection {
  _Selection(this.place, {this.loading = false, this.dropped = false});
  SavedPlace place;
  bool loading;

  /// A long-press pin rather than a known place.
  final bool dropped;
}

/// Directions to a place: the start, the travel mode and the routes found.
class _Trip {
  _Trip({required this.to, required this.from, required this.fromLabel});
  final SavedPlace to;
  LatLng from;
  String fromLabel;
  MapelevenTravelMode mode = MapelevenTravelMode.car;
  List<MapelevenRoute> routes = const [];
  int chosen = 0;
  bool loading = true;
  String? error;
  bool showSteps = false;
}

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key, required this.state});
  final AppState state;

  @override
  State<ExplorePage> createState() => ExplorePageState();
}

class ExplorePageState extends State<ExplorePage> {
  MapelevenController? _map;
  _Selection? _selected;
  _Trip? _trip;
  int _tripSeq = 0;
  String? _category;
  List<SavedPlace> _results = const [];
  bool _loadingCategory = false;
  int _selectSeq = 0;

  AppState get state => widget.state;
  S get s => S(state.language);

  /// Opens a saved place (from the Saved tab).
  void showSaved(SavedPlace place) => _select(place);

  Future<void> _onMapReady(MapelevenController map) async {
    _map = map;
    await map.registerIcon(await MapelevenIcon.pin('selected', color: const Color(0xFFDC2626), icon: Icons.circle));
    await map.registerIcon(
      await MapelevenIcon.fromIconData('start', Icons.trip_origin, background: const Color(0xFF4285F4), size: 24),
    );
    for (final (key, icon, _) in categories) {
      await map.registerIcon(await MapelevenIcon.fromIconData('cat-$key', icon, background: brand, size: 30));
    }
    map.markerTaps.listen((m) {
      if (m.data is SavedPlace) _select(m.data! as SavedPlace, fly: false);
    });
    // A shared link (https://mapeleven.dev/explorer/#31.95,35.91) opens that point.
    if (kIsWeb) {
      final parts = Uri.base.fragment.split(',');
      final lat = parts.length == 2 ? double.tryParse(parts[0]) : null;
      final lng = parts.length == 2 ? double.tryParse(parts[1]) : null;
      if (lat != null && lng != null) _dropPin(LatLng(lat, lng));
    }
  }

  // ── Selecting places ──────────────────────────────────────────────────────

  Future<void> _select(
    SavedPlace place, {
    bool fly = true,
    bool lookUpAddress = false,
    bool dropped = false,
    LatLngBounds? bounds,
  }) async {
    final seq = ++_selectSeq;
    setState(() => _selected = _Selection(place, loading: lookUpAddress, dropped: dropped));
    final map = _map;
    if (map == null) return;
    await map.addMarker(place.position, id: 'selected', icon: 'selected', anchor: MapelevenAnchor.bottom);
    if (bounds != null) {
      await map.fitBounds(bounds, padding: 60);
    } else if (fly) {
      await map.flyTo(place.position, zoom: 16);
    }
    if (!lookUpAddress) return;
    // Fill in the address (and a name for dropped pins) from reverse geocoding.
    final found = await map.search.reverse(place.position, language: state.language).catchError((_) => null);
    if (!mounted || seq != _selectSeq) return;
    setState(() {
      _selected = _Selection(
        SavedPlace(
          name: place.name.isEmpty ? (found?.name.isNotEmpty == true ? found!.name : s.droppedPin) : place.name,
          address: found == null ? '' : (place.name.isEmpty ? found.address : found.label()),
          position: place.position,
          kind: place.kind ?? found?.type,
        ),
        dropped: dropped,
      );
    });
  }

  void _dropPin(LatLng p) =>
      _select(SavedPlace(name: '', address: '', position: p), lookUpAddress: true, fly: false, dropped: true);

  Future<void> _contribute(_Selection selection) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ContributePage(
        state: state,
        position: selection.place.position,
        place: selection.dropped ? null : selection.place,
      ),
    ),
  );

  void _onPoiTap(MapelevenPoi poi) => _select(
    SavedPlace(name: poi.name, address: '', position: poi.position, kind: poi.kind),
    lookUpAddress: true,
    fly: false,
  );

  Future<void> _clear() async {
    _selectSeq++;
    setState(() => _selected = null);
    await _map?.removeMarker('selected');
  }

  // ── Categories ────────────────────────────────────────────────────────────

  Future<void> _toggleCategory(String key) async {
    final map = _map;
    if (map == null) return;
    await _clear();
    await _clearResults();
    if (_category == key) return;
    setState(() {
      _category = key;
      _loadingCategory = true;
    });
    final kinds = categories.firstWhere((c) => c.$1 == key).$3;
    if ((map.zoom ?? 0) < 14.5) {
      await map.flyTo(map.center ?? amman, zoom: 15);
      await Future<void>.delayed(const Duration(milliseconds: 1200));
    }
    // Everything in the loaded tiles first (instant, no server call)...
    var places = (await map.nearbyPois(
      kinds: kinds,
      limit: 40,
    )).map((p) => SavedPlace(name: p.name, address: '', position: p.position, kind: p.kind)).toList();
    // ...then the search server when the area has none.
    if (places.isEmpty) {
      final found = await map.search
          .search(
            s.category(key),
            language: state.language,
            near: map.center,
            osmTags: kinds.map((k) => 'amenity:$k').toList(),
            limit: 20,
          )
          .catchError((_) => <MapelevenPlace>[]);
      places = found.map(SavedPlace.fromPlace).toList();
    }
    if (!mounted || _category != key) return;
    setState(() {
      _results = places.take(40).toList();
      _loadingCategory = false;
    });
    for (final (i, p) in _results.indexed) {
      await map.addMarker(p.position, id: 'r$i', icon: 'cat-$key', data: p);
    }
    if (_results.length > 1) await map.fitPoints(_results.map((p) => p.position).toList(), padding: 70);
  }

  Future<void> _clearResults() async {
    for (var i = 0; i < _results.length; i++) {
      await _map?.removeMarker('r$i');
    }
    setState(() {
      _results = const [];
      _category = null;
      _loadingCategory = false;
      _listExpanded = false;
    });
  }

  // ── Search, location, actions ─────────────────────────────────────────────

  Future<void> _openSearch() async {
    final map = _map;
    if (map == null) return;
    final result = await Navigator.of(context).push<SearchResult>(
      MaterialPageRoute(
        builder: (_) => SearchPage(state: state, search: map.search, near: map.center ?? amman),
      ),
    );
    if (result == null) return;
    await _clearResults();
    state.addRecent(result.place);
    await _select(result.place, bounds: result.bounds);
  }

  Future<void> _locate() async {
    final here = await state.locate();
    if (!mounted) return;
    if (here == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.locationOff)));
      return;
    }
    await _map?.flyTo(here, zoom: 16);
  }

  /// Opens directions to [p] inside the app; other map apps when the
  /// provider has no routing service.
  Future<void> _directions(SavedPlace p) async {
    final map = _map;
    if (map == null) return;
    if (!map.router.available) return _directionsElsewhere(p);
    var from = state.myLocation ?? await state.locate();
    var label = s.yourLocation;
    if (!mounted) return;
    if (from == null) {
      from = map.center ?? amman;
      label = s.mapCentre;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.locationOff)));
    }
    setState(() => _trip = _Trip(to: p, from: from!, fromLabel: label));
    await _loadRoute();
  }

  Future<void> _loadRoute() async {
    final trip = _trip, map = _map;
    if (trip == null || map == null) return;
    final seq = ++_tripSeq;
    setState(() {
      trip.loading = true;
      trip.error = null;
    });
    await map.addMarker(trip.from, id: 'route-start', icon: 'start');
    try {
      final routes = await map.router.route(
        [trip.from, trip.to.position],
        mode: trip.mode,
        language: state.language,
        alternatives: 2,
      );
      if (!mounted || seq != _tripSeq) return;
      setState(() {
        trip.routes = routes;
        trip.chosen = 0;
        trip.loading = false;
      });
      await _drawRoute();
    } catch (e) {
      if (!mounted || seq != _tripSeq) return;
      setState(() {
        trip.routes = const [];
        trip.loading = false;
        trip.error = e is MapelevenRoutingException && e.noRoute ? s.noRoute : s.routeFailed;
      });
      await map.clearRoute();
    }
  }

  Future<void> _drawRoute() async {
    final trip = _trip;
    if (trip == null || trip.routes.isEmpty) return;
    final size = MediaQuery.sizeOf(context);
    await _map?.showRoute(
      trip.routes[trip.chosen],
      alternatives: [for (final (i, r) in trip.routes.indexed) if (i != trip.chosen) r],
      // On the web the map already stops at the sheet (see build), so less bottom padding.
      padding: (
        left: 40,
        top: MediaQuery.paddingOf(context).top + 150,
        right: 40,
        bottom: kIsWeb ? 40 : math.max(_sheetHeight, size.height * 0.3) + 24,
      ),
    );
  }

  Future<void> _closeTrip() async {
    _tripSeq++;
    setState(() => _trip = null);
    await _map?.clearRoute();
    await _map?.removeMarker('route-start');
  }

  Future<void> _chooseStart() async {
    final map = _map, trip = _trip;
    if (map == null || trip == null) return;
    final result = await Navigator.of(context).push<SearchResult>(
      MaterialPageRoute(builder: (_) => SearchPage(state: state, search: map.search, near: map.center ?? amman)),
    );
    if (result == null || _trip != trip) return;
    trip.from = result.place.position;
    trip.fromLabel = result.place.name;
    await _loadRoute();
  }

  Future<void> _directionsElsewhere(SavedPlace p) async {
    final lat = p.position.latitude, lng = p.position.longitude;
    final uri = kIsWeb
        ? Uri.parse('https://www.openstreetmap.org/directions?to=$lat%2C$lng')
        : defaultTargetPlatform == TargetPlatform.iOS
        ? Uri.parse('https://maps.apple.com/?daddr=$lat,$lng')
        : Uri.parse('geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(p.name)})');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _share(SavedPlace p) async {
    final lat = p.position.latitude.toStringAsFixed(6), lng = p.position.longitude.toStringAsFixed(6);
    await Clipboard.setData(ClipboardData(text: '${p.name}\nhttps://mapeleven.dev/explorer/#$lat,$lng'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.copied), duration: const Duration(seconds: 1)));
  }

  /// Height of the bottom sheet, measured after layout, so the location
  /// button and the map credit sit just above it (as in other map apps).
  double _sheetHeight = 0;
  bool _listExpanded = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final selected = _selected;
        final trip = _trip;
        final hasSheet = selected != null || _category != null || trip != null;
        final sheetH = hasSheet ? _sheetHeight : 0.0;
        final top = MediaQuery.paddingOf(context).top;
        final rtl = s.ar;
        Widget? sheet;
        if (trip != null) {
          sheet = _DirectionsSheet(
            trip: trip,
            s: s,
            onMode: (m) {
              trip.mode = m;
              _loadRoute();
            },
            onChoose: (i) {
              setState(() => trip.chosen = i);
              _drawRoute();
            },
            onToggleSteps: () => setState(() => trip.showSteps = !trip.showSteps),
            onClose: _closeTrip,
          );
        } else if (selected != null) {
          sheet = _PlaceSheet(
            selection: selected,
            s: s,
            from: state.myLocation,
            saved: state.isSaved(selected.place),
            onClose: _clear,
            onDirections: () => _directions(selected.place),
            onSave: () => state.toggleSaved(selected.place),
            onShare: () => _share(selected.place),
            onCopy: () => _copyCoordinates(selected.place),
            onContribute: () => _contribute(selected),
          );
        } else if (_category != null) {
          sheet = _ResultsSheet(
            category: _category!,
            loading: _loadingCategory,
            results: _results,
            s: s,
            expanded: _listExpanded,
            from: state.myLocation ?? _map?.center,
            onTap: (p) => _select(p),
            onClose: _clearResults,
            onExpand: (v) => setState(() => _listExpanded = v),
          );
        }
        return Stack(
          children: [
            // The map runs under the sheet; the OSM credit (required by the
            // ODbL) is lifted above the sheet so it is never covered.
            // MapLibre GL JS (web) ignores the margins below, so on the web the
            // map stops at the sheet instead of running under it.
            Positioned.fill(
              bottom: kIsWeb ? math.max(0, sheetH - 18) : 0,
              child: MapelevenMap(
                provider: provider,
                language: state.language,
                theme: state.theme,
                imagery: state.activeImagery,
                initialCenter: amman,
                initialZoom: 13,
                showUserLocation: state.myLocation != null,
                onMapReady: _onMapReady,
                onPoiTap: _onPoiTap,
                onLongPress: _dropPin,
                onTap: (_) {
                  if (_selected != null && _trip == null) _clear();
                },
                compassPosition: kIsWeb ? null : (rtl ? CompassViewPosition.topLeft : CompassViewPosition.topRight),
                compassMargins: math.Point(18, top + 176),
                attributionMargins: math.Point(8, sheetH + 8),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (trip != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: _TripHeader(trip: trip, s: s, onBack: _closeTrip, onFrom: _chooseStart),
                    )
                  else ...[
                    Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 0), child: _searchBar()),
                    SizedBox(height: 52, child: _chips()),
                  ],
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                      child: MapButton(
                        icon: Icons.layers_outlined,
                        tooltip: s.layers,
                        onPressed: () => showLayersSheet(context, state),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedPositionedDirectional(
              duration: const Duration(milliseconds: 180),
              end: 12,
              // Above the sheet and clear of the map credit button.
              bottom: sheetH + 44,
              child: MapButton(icon: Icons.my_location, color: brand, onPressed: _locate),
            ),
            if (sheet != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _MeasureSize(
                  onChange: (size) {
                    if (size.height != _sheetHeight) setState(() => _sheetHeight = size.height);
                  },
                  child: sheet,
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _copyCoordinates(SavedPlace p) async {
    final text = '${p.position.latitude.toStringAsFixed(6)}, ${p.position.longitude.toStringAsFixed(6)}';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.copied), duration: const Duration(seconds: 1)));
  }

  Widget _searchBar() {
    return Material(
      elevation: 3,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(28),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: _openSearch,
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              const SizedBox(width: 16),
              const Icon(Icons.search, color: Colors.black54),
              const SizedBox(width: 12),
              Expanded(
                child: Text(s.searchHint, style: const TextStyle(color: Colors.black54, fontSize: 16)),
              ),
              const SizedBox(width: 8),
              // Language switch where map apps put the account picture.
              InkWell(
                customBorder: const CircleBorder(),
                onTap: () => state.setLanguage(s.ar ? MapelevenLanguage.en : MapelevenLanguage.ar),
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: brand,
                  child: Text(
                    s.ar ? 'EN' : 'ع',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chips() {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        for (final (key, icon, _) in categories)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: FilterChip(
              avatar: Icon(icon, size: 18, color: _category == key ? Colors.white : brand),
              label: Text(s.category(key)),
              selected: _category == key,
              showCheckmark: false,
              selectedColor: brand,
              labelStyle: TextStyle(color: _category == key ? Colors.white : Colors.black87),
              backgroundColor: Colors.white,
              elevation: 2,
              shadowColor: Colors.black38,
              side: BorderSide.none,
              shape: const StadiumBorder(),
              onSelected: (_) => _toggleCategory(key),
            ),
          ),
      ],
    );
  }
}

/// Reports its child's size after each layout.
class _MeasureSize extends StatefulWidget {
  const _MeasureSize({required this.onChange, required this.child});
  final void Function(Size size) onChange;
  final Widget child;

  @override
  State<_MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<_MeasureSize> {
  Size? _last;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = context.size;
      if (!mounted || size == null || size == _last) return;
      _last = size;
      widget.onChange(size);
    });
    return widget.child;
  }
}

/// White bottom sheet with a drag handle: swipe down to close, up to expand.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.child, this.onSwipeDown, this.onSwipeUp});
  final Widget child;
  final VoidCallback? onSwipeDown, onSwipeUp;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v > 250) onSwipeDown?.call();
        if (v < -250) onSwipeUp?.call();
      },
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, -2))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 8, bottom: 6),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _PlaceSheet extends StatelessWidget {
  const _PlaceSheet({
    required this.selection,
    required this.s,
    required this.from,
    required this.saved,
    required this.onClose,
    required this.onDirections,
    required this.onSave,
    required this.onShare,
    required this.onCopy,
    required this.onContribute,
  });

  final _Selection selection;
  final S s;
  final LatLng? from;
  final bool saved;
  final VoidCallback onClose, onDirections, onSave, onShare, onCopy, onContribute;

  @override
  Widget build(BuildContext context) {
    final p = selection.place;
    final kind = s.kind(p.kind);
    final distance = from == null ? null : s.km(distanceKm(from!, p.position));
    final subtitle = [if (kind.isNotEmpty) kind, ?distance].join(' · ');
    final text = Theme.of(context).textTheme;
    final address = selection.loading ? s.locating : p.address;
    final coords = '${p.position.latitude.toStringAsFixed(5)}, ${p.position.longitude.toStringAsFixed(5)}';
    return _Sheet(
      onSwipeDown: onClose,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    p.name.isEmpty ? s.locating : p.name,
                    style: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.close, size: 20),
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFFF1F3F4)),
                  onPressed: onClose,
                ),
              ],
            ),
            if (subtitle.isNotEmpty)
              Text(subtitle, style: text.bodyMedium?.copyWith(color: Colors.black54)),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilledButton.icon(
                    onPressed: onDirections,
                    icon: const Icon(Icons.directions, size: 20),
                    label: Text(s.directions),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: onSave,
                    icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border, size: 20),
                    label: Text(saved ? s.unsave : s.save),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: onShare,
                    icon: const Icon(Icons.share_outlined, size: 20),
                    label: Text(s.share),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            if (address.isNotEmpty) _InfoRow(icon: Icons.place_outlined, text: address),
            _InfoRow(icon: Icons.pin_drop_outlined, text: coords, ltr: true, onTap: onCopy),
            _InfoRow(
              icon: selection.dropped ? Icons.add_location_alt_outlined : Icons.edit_location_alt_outlined,
              text: selection.dropped ? s.addPlace : s.suggestEdit,
              onTap: onContribute,
              action: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text, this.ltr = false, this.onTap, this.action = false});
  final IconData icon;
  final String text;
  final bool ltr;
  final VoidCallback? onTap;

  /// Styled as a link that opens something, rather than copyable info.
  final bool action;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: brand, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textDirection: ltr ? TextDirection.ltr : null,
                textAlign: TextAlign.start,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: action ? brand : null,
                  fontWeight: action ? FontWeight.w600 : null,
                ),
              ),
            ),
            if (onTap != null && !action) const Icon(Icons.copy, size: 18, color: Colors.black38),
            if (action) Icon(Icons.chevron_right, color: brand.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}

class _ResultsSheet extends StatelessWidget {
  const _ResultsSheet({
    required this.category,
    required this.loading,
    required this.results,
    required this.s,
    required this.expanded,
    required this.from,
    required this.onTap,
    required this.onClose,
    required this.onExpand,
  });

  final String category;
  final bool loading;
  final List<SavedPlace> results;
  final S s;
  final bool expanded;
  final LatLng? from;
  final void Function(SavedPlace) onTap;
  final VoidCallback onClose;
  final void Function(bool expanded) onExpand;

  @override
  Widget build(BuildContext context) {
    final icon = categories.firstWhere((c) => c.$1 == category).$2;
    final height = MediaQuery.sizeOf(context).height * (expanded ? 0.62 : 0.32);
    return _Sheet(
      onSwipeUp: () => onExpand(true),
      onSwipeDown: () => expanded ? onExpand(false) : onClose(),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: height),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.category(category),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          loading ? s.searching : (results.isEmpty ? s.noResults : s.nPlaces(results.length)),
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.close, size: 20),
                    style: IconButton.styleFrom(backgroundColor: const Color(0xFFF1F3F4)),
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            if (loading) const LinearProgressIndicator(minHeight: 2),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: results.length,
                separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
                itemBuilder: (context, i) {
                  final p = results[i];
                  final kind = s.kind(p.kind);
                  final distance = from == null ? null : s.km(distanceKm(from!, p.position));
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: brand.withValues(alpha: 0.12),
                      child: Icon(icon, color: brand, size: 20),
                    ),
                    title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text([if (kind.isNotEmpty) kind, ?distance].join(' · ')),
                    onTap: () => onTap(p),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// From and To, above the map while directions are open.
class _TripHeader extends StatelessWidget {
  const _TripHeader({required this.trip, required this.s, required this.onBack, required this.onFrom});
  final _Trip trip;
  final S s;
  final VoidCallback onBack, onFrom;

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, Color color, String label, String text, VoidCallback? onTap) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFFF1F3F4), borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Text('$label  ', style: const TextStyle(color: Colors.black54)),
            Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
    return Material(
      elevation: 3,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(18),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 12, 8),
        child: Row(
          children: [
            IconButton(icon: const BackButtonIcon(), onPressed: onBack),
            Expanded(
              child: Column(
                children: [
                  row(Icons.trip_origin, const Color(0xFF4285F4), s.from, trip.fromLabel, onFrom),
                  const SizedBox(height: 6),
                  row(Icons.place, const Color(0xFFDC2626), s.to, trip.to.name, null),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectionsSheet extends StatelessWidget {
  const _DirectionsSheet({
    required this.trip,
    required this.s,
    required this.onMode,
    required this.onChoose,
    required this.onToggleSteps,
    required this.onClose,
  });

  final _Trip trip;
  final S s;
  final void Function(MapelevenTravelMode) onMode;
  final void Function(int) onChoose;
  final VoidCallback onToggleSteps, onClose;

  static const _modeIcons = {
    MapelevenTravelMode.car: Icons.directions_car,
    MapelevenTravelMode.walk: Icons.directions_walk,
    MapelevenTravelMode.bike: Icons.directions_bike,
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final route = trip.routes.isEmpty ? null : trip.routes[trip.chosen];
    return _Sheet(
      onSwipeDown: trip.showSteps ? onToggleSteps : onClose,
      onSwipeUp: trip.showSteps || route == null ? null : onToggleSteps,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final m in MapelevenTravelMode.values)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: ChoiceChip(
                              avatar: Icon(_modeIcons[m], size: 18, color: trip.mode == m ? Colors.white : brand),
                              label: Text(s.travelMode(m)),
                              selected: trip.mode == m,
                              showCheckmark: false,
                              selectedColor: brand,
                              labelStyle: TextStyle(color: trip.mode == m ? Colors.white : Colors.black87),
                              onSelected: (_) => onMode(m),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.close, size: 20),
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFFF1F3F4)),
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (trip.loading) ...[
              const LinearProgressIndicator(minHeight: 2),
              Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(s.routing)),
            ] else if (trip.error != null)
              Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(trip.error!))
            else if (route != null) ...[
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: s.duration(route.duration),
                      style: text.headlineSmall?.copyWith(color: const Color(0xFF188038), fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: '  (${s.km(route.distanceMeters / 1000)})', style: text.titleMedium),
                  ],
                ),
              ),
              Text(s.noTraffic, style: text.bodySmall?.copyWith(color: Colors.black54)),
              if (trip.routes.length > 1) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final (i, r) in trip.routes.indexed)
                      ChoiceChip(
                        label: Text('${s.routeN(i + 1)} · ${s.duration(r.duration)}'),
                        selected: trip.chosen == i,
                        onSelected: (_) => onChoose(i),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: onToggleSteps,
                icon: Icon(trip.showSteps ? Icons.expand_more : Icons.format_list_bulleted),
                label: Text(s.steps),
              ),
              if (trip.showSteps)
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.38),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: route.steps.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
                    itemBuilder: (context, i) {
                      final step = route.steps[i];
                      return ListTile(
                        dense: true,
                        // Arrows must point the real way, so they are never mirrored in Arabic.
                        leading: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Icon(_maneuverIcon(step.maneuver), color: Colors.black87),
                        ),
                        title: Text(step.instruction, style: text.bodyMedium),
                        subtitle: step.distanceMeters > 0 ? Text(s.km(step.distanceMeters / 1000)) : null,
                      );
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

IconData _maneuverIcon(MapelevenManeuver m) => switch (m) {
  MapelevenManeuver.start => Icons.trip_origin,
  MapelevenManeuver.arrive => Icons.place,
  MapelevenManeuver.continueStraight => Icons.straight,
  MapelevenManeuver.slightRight => Icons.turn_slight_right,
  MapelevenManeuver.right => Icons.turn_right,
  MapelevenManeuver.sharpRight => Icons.turn_sharp_right,
  MapelevenManeuver.uTurn => Icons.u_turn_left,
  MapelevenManeuver.sharpLeft => Icons.turn_sharp_left,
  MapelevenManeuver.left => Icons.turn_left,
  MapelevenManeuver.slightLeft => Icons.turn_slight_left,
  MapelevenManeuver.rampRight || MapelevenManeuver.exitRight => Icons.ramp_right,
  MapelevenManeuver.rampLeft || MapelevenManeuver.exitLeft => Icons.ramp_left,
  MapelevenManeuver.keepRight => Icons.fork_right,
  MapelevenManeuver.keepLeft => Icons.fork_left,
  MapelevenManeuver.merge => Icons.merge,
  MapelevenManeuver.roundabout || MapelevenManeuver.roundaboutExit => Icons.roundabout_right,
  MapelevenManeuver.ferry => Icons.directions_boat,
  MapelevenManeuver.other => Icons.straight,
};
