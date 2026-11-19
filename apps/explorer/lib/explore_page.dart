import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapeleven/mapeleven.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart';
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
  _Selection(this.place, {this.loading = false});
  SavedPlace place;
  bool loading;
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

  Future<void> _select(SavedPlace place, {bool fly = true, bool lookUpAddress = false, LatLngBounds? bounds}) async {
    final seq = ++_selectSeq;
    setState(() => _selected = _Selection(place, loading: lookUpAddress));
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
      );
    });
  }

  void _dropPin(LatLng p) => _select(SavedPlace(name: '', address: '', position: p), lookUpAddress: true, fly: false);

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

  Future<void> _directions(SavedPlace p) async {
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final selected = _selected;
        // The panel sits under the map, not over it, so the map's OSM
        // attribution (required by the ODbL) is never covered.
        return Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
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
                        if (_selected != null) _clear();
                      },
                    ),
                  ),
                  SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 0), child: _searchBar()),
                        SizedBox(height: 48, child: _chips()),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: MapButton(
                              icon: Icons.layers_outlined,
                              tooltip: s.layers,
                              onPressed: () => showLayersSheet(context, state),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: Padding(
                            // Clear of the OSM attribution button in the map's bottom corner.
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 44),
                            child: MapButton(icon: Icons.my_location, color: brand, onPressed: _locate),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (selected != null)
              _PlaceCard(
                selection: selected,
                s: s,
                from: state.myLocation,
                saved: state.isSaved(selected.place),
                onClose: _clear,
                onDirections: () => _directions(selected.place),
                onSave: () => state.toggleSaved(selected.place),
                onShare: () => _share(selected.place),
              )
            else if (_category != null)
              _ResultsPanel(
                title: s.category(_category!),
                loading: _loadingCategory,
                results: _results,
                s: s,
                from: state.myLocation ?? _map?.center,
                onTap: (p) => _select(p),
                onClose: _clearResults,
              ),
          ],
        );
      },
    );
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
              TextButton(
                onPressed: () => state.setLanguage(s.ar ? MapelevenLanguage.en : MapelevenLanguage.ar),
                child: Text(s.ar ? 'EN' : 'ع', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              const SizedBox(width: 6),
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

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.selection,
    required this.s,
    required this.from,
    required this.saved,
    required this.onClose,
    required this.onDirections,
    required this.onSave,
    required this.onShare,
  });

  final _Selection selection;
  final S s;
  final LatLng? from;
  final bool saved;
  final VoidCallback onClose, onDirections, onSave, onShare;

  @override
  Widget build(BuildContext context) {
    final p = selection.place;
    final kind = s.kind(p.kind);
    final distance = from == null ? null : s.km(distanceKm(from!, p.position));
    final subtitle = [if (kind.isNotEmpty) kind, ?distance].join(' · ');
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 8, 12),
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
                IconButton(icon: const Icon(Icons.close), onPressed: onClose),
              ],
            ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                style: text.bodyMedium?.copyWith(color: brand, fontWeight: FontWeight.w500),
              ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 10),
              child: Text(
                selection.loading ? s.locating : p.address,
                style: text.bodyMedium?.copyWith(color: Colors.black54),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilledButton.icon(
                    onPressed: onDirections,
                    icon: const Icon(Icons.directions),
                    label: Text(s.directions),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: onSave,
                    icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
                    label: Text(saved ? s.unsave : s.save),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(onPressed: onShare, icon: const Icon(Icons.share_outlined), label: Text(s.share)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${p.position.latitude.toStringAsFixed(5)}, ${p.position.longitude.toStringAsFixed(5)}  ·  © OpenStreetMap',
              style: text.bodySmall?.copyWith(color: Colors.black38),
              textDirection: TextDirection.ltr,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsPanel extends StatelessWidget {
  const _ResultsPanel({
    required this.title,
    required this.loading,
    required this.results,
    required this.s,
    required this.from,
    required this.onTap,
    required this.onClose,
  });

  final String title;
  final bool loading;
  final List<SavedPlace> results;
  final S s;
  final LatLng? from;
  final void Function(SavedPlace) onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      elevation: 6,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(loading ? s.searching : (results.isEmpty ? s.noResults : s.nPlaces(results.length))),
              trailing: IconButton(icon: const Icon(Icons.close), onPressed: onClose),
            ),
            if (loading) const LinearProgressIndicator(minHeight: 2),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: results.length,
                itemBuilder: (context, i) {
                  final p = results[i];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: brand.withValues(alpha: 0.12),
                      child: Text('${i + 1}', style: const TextStyle(color: brand, fontSize: 12)),
                    ),
                    title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(s.kind(p.kind)),
                    trailing: from == null ? null : Text(s.km(distanceKm(from!, p.position))),
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
