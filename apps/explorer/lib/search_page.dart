import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapeleven/mapeleven.dart';

import 'app_state.dart';
import 'main.dart';
import 'strings.dart';

class SearchResult {
  const SearchResult(this.place, this.bounds);
  final SavedPlace place;

  /// Set for areas (cities, districts), so the map can frame the whole area.
  final LatLngBounds? bounds;
}

/// Full-screen search with results as you type, ranked near the map centre.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.state, required this.search, required this.near});
  final AppState state;
  final MapelevenSearch search;
  final LatLng near;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<MapelevenPlace> _results = const [];
  bool _loading = false;
  int _seq = 0;

  S get s => S(widget.state.language);

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _run(q));
  }

  Future<void> _run(String q) async {
    final seq = ++_seq;
    if (q.trim().length < 2) {
      setState(() {
        _results = const [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    final results = await widget.search
        .search(q, language: widget.state.language, near: widget.near, limit: 12)
        .catchError((_) => <MapelevenPlace>[]);
    if (!mounted || seq != _seq) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showRecent = _query.text.trim().length < 2;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 0,
        title: TextField(
          controller: _query,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(hintText: s.searchHint, border: InputBorder.none),
          onChanged: _onChanged,
          onSubmitted: _run,
        ),
        actions: [
          if (_query.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _query.clear();
                _onChanged('');
              },
            ),
        ],
        bottom: _loading
            ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2))
            : null,
      ),
      body: showRecent ? _recent() : _list(),
    );
  }

  Widget _recent() {
    final recent = widget.state.recent;
    if (recent.isEmpty) return const SizedBox.shrink();
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(s.recent, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.black54)),
        ),
        for (final p in recent)
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFF1F5F9),
              child: Icon(Icons.history, color: Colors.black54),
            ),
            title: Text(p.name),
            subtitle: Text(p.address, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => Navigator.pop(context, SearchResult(p, null)),
          ),
      ],
    );
  }

  Widget _list() {
    if (!_loading && _results.isEmpty) return Center(child: Text(s.noResults));
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, i) {
        final p = _results[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: brand.withValues(alpha: 0.1),
            child: Icon(_iconFor(p.type), color: brand),
          ),
          title: Text(p.name),
          subtitle: Text(
            [s.kind(p.type), p.address].where((e) => e.isNotEmpty).join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(s.km(distanceKm(widget.near, p.position)), style: const TextStyle(color: Colors.black54)),
          onTap: () => Navigator.pop(context, SearchResult(SavedPlace.fromPlace(p), p.bounds)),
        );
      },
    );
  }

  static IconData _iconFor(String? type) => switch (type) {
    'city' || 'town' || 'village' || 'state' || 'country' || 'county' => Icons.location_city,
    'suburb' || 'neighbourhood' || 'quarter' || 'residential' => Icons.holiday_village_outlined,
    'restaurant' || 'fast_food' => Icons.restaurant,
    'cafe' => Icons.local_cafe,
    'pharmacy' || 'chemist' => Icons.local_pharmacy,
    'hospital' || 'clinic' || 'doctors' => Icons.local_hospital,
    'fuel' => Icons.local_gas_station,
    'place_of_worship' => Icons.mosque,
    'school' || 'university' || 'college' => Icons.school,
    'hotel' => Icons.hotel,
    'bank' || 'atm' => Icons.account_balance,
    'supermarket' || 'convenience' || 'mall' => Icons.shopping_bag_outlined,
    'park' => Icons.park,
    'primary' || 'secondary' || 'tertiary' || 'residential_road' || 'street' || 'trunk' || 'motorway' => Icons.add_road,
    _ => Icons.place_outlined,
  };
}
