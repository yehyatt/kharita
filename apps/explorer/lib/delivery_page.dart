import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mapeleven/mapeleven.dart';

import 'app_state.dart';
import 'main.dart';
import 'strings.dart';

/// Sample delivery zone over central and west Amman, as [lng, lat] pairs.
const _zone = [
  [35.800, 31.935],
  [35.815, 32.020],
  [35.880, 32.040],
  [35.950, 32.030],
  [35.975, 31.960],
  [35.930, 31.905],
  [35.850, 31.905],
  [35.800, 31.935],
];

/// Sample distributors inside the zone (fixed seed, so they stay put).
final _distributors = () {
  final rnd = math.Random(11);
  final out = <(String, LatLng)>[];
  while (out.length < 28) {
    final p = LatLng(31.905 + rnd.nextDouble() * 0.135, 35.80 + rnd.nextDouble() * 0.175);
    if (_inZone(p)) out.add(('#${out.length + 1}', p));
  }
  return out;
}();

bool _inZone(LatLng p) {
  var inside = false;
  for (var i = 0, j = _zone.length - 1; i < _zone.length; j = i++) {
    final xi = _zone[i][0], yi = _zone[i][1], xj = _zone[j][0], yj = _zone[j][1];
    if ((yi > p.latitude) != (yj > p.latitude) && p.longitude < (xj - xi) * (p.latitude - yi) / (yj - yi) + xi) {
      inside = !inside;
    }
  }
  return inside;
}

enum _Phase { pick, tracking, arrived }

/// Delivery demo: pick an address with a fixed centre pin, check it against a
/// delivery zone, then follow a simulated driver to the door.
class DeliveryPage extends StatefulWidget {
  const DeliveryPage({super.key, required this.state});
  final AppState state;

  @override
  State<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  static const _speedKmh = 30.0;

  MapelevenController? _map;
  _Phase _phase = _Phase.pick;
  LatLng _pin = const LatLng(31.9566, 35.8722);
  String? _address;
  bool _resolving = false;
  int _reverseSeq = 0;

  // Tracking
  List<LatLng> _route = const [];
  double _progress = 0;
  String _distributor = '';
  Timer? _timer;

  S get s => S(widget.state.language);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _onMapReady(MapelevenController map) async {
    _map = map;
    await map.registerIcon(
      await MapelevenIcon.fromIconData('truck', Icons.local_shipping, background: accent, size: 40),
    );
    await map.registerIcon(await MapelevenIcon.pin('home', color: brand, icon: Icons.home));
    await map.addGeoJson('zone', {
      'type': 'Feature',
      'properties': <String, dynamic>{},
      'geometry': {
        'type': 'Polygon',
        'coordinates': [_zone],
      },
    }, options: const MapelevenGeoJsonOptions(color: brand, fillOpacity: 0.06, dashed: true));
    await map.addGeoJson('distributors', {
      'type': 'FeatureCollection',
      'features': [
        for (final (name, p) in _distributors)
          {
            'type': 'Feature',
            'properties': {'name': name},
            'geometry': {
              'type': 'Point',
              'coordinates': [p.longitude, p.latitude],
            },
          },
      ],
    }, options: const MapelevenGeoJsonOptions(cluster: true, color: Color(0xFF64748B), radius: 5));
    _onCameraIdle(map.center ?? _pin, 15);
  }

  Future<void> _onCameraIdle(LatLng center, double zoom) async {
    if (_phase != _Phase.pick) return;
    final seq = ++_reverseSeq;
    setState(() {
      _pin = center;
      _resolving = true;
    });
    final place = await _map?.search.reverse(center, language: widget.state.language).catchError((_) => null);
    if (!mounted || seq != _reverseSeq) return;
    setState(() {
      _address = place?.label();
      _resolving = false;
    });
  }

  Future<void> _confirm() async {
    final map = _map;
    if (map == null) return;
    // Nearest distributor drives to the address along a street-like path.
    final (name, from) = _distributors.reduce((a, b) => distanceKm(a.$2, _pin) < distanceKm(b.$2, _pin) ? a : b);
    final corner = LatLng(from.latitude, _pin.longitude);
    final mid = LatLng((from.latitude + corner.latitude) / 2 + 0.002, (from.longitude + corner.longitude) / 2);
    setState(() {
      _phase = _Phase.tracking;
      _distributor = name;
      _route = [from, mid, corner, _pin];
      _progress = 0;
    });
    await map.addMarker(_pin, id: 'home', icon: 'home', anchor: MapelevenAnchor.bottom);
    await map.addMarker(from, id: 'truck', icon: 'truck');
    await _drawRemaining();
    await map.fitPoints(_route, padding: 80);
    // Compressed time: the whole trip plays in about 40 seconds.
    _timer = Timer.periodic(const Duration(milliseconds: 400), (_) => _tick());
  }

  Future<void> _tick() async {
    _progress = math.min(1, _progress + 0.01);
    final (pos, _) = _along(_progress);
    // A round badge stays upright; pass rotation: heading for arrow-shaped icons.
    await _map?.moveMarker('truck', pos);
    await _drawRemaining();
    if (!mounted) return;
    if (_progress >= 1) {
      _timer?.cancel();
      setState(() => _phase = _Phase.arrived);
    } else {
      setState(() {});
    }
  }

  /// Position and heading at [t] (0..1) of the route length.
  (LatLng, double) _along(double t) {
    final legs = [for (var i = 0; i < _route.length - 1; i++) distanceKm(_route[i], _route[i + 1])];
    var target = t * legs.fold(0.0, (a, b) => a + b);
    for (var i = 0; i < legs.length; i++) {
      if (target <= legs[i] || i == legs.length - 1) {
        final f = legs[i] == 0 ? 1.0 : (target / legs[i]).clamp(0.0, 1.0);
        final a = _route[i], b = _route[i + 1];
        return (
          LatLng(a.latitude + (b.latitude - a.latitude) * f, a.longitude + (b.longitude - a.longitude) * f),
          bearing(a, b),
        );
      }
      target -= legs[i];
    }
    return (_route.last, 0);
  }

  double get _remainingKm {
    final legs = [for (var i = 0; i < _route.length - 1; i++) distanceKm(_route[i], _route[i + 1])];
    return legs.fold(0.0, (a, b) => a + b) * (1 - _progress);
  }

  Future<void> _drawRemaining() async {
    final map = _map;
    if (map == null) return;
    final (pos, _) = _along(_progress);
    // Points still ahead of the truck.
    final legs = [for (var i = 0; i < _route.length - 1; i++) distanceKm(_route[i], _route[i + 1])];
    final total = legs.fold(0.0, (a, b) => a + b);
    var covered = 0.0;
    final ahead = <LatLng>[pos];
    for (var i = 0; i < legs.length; i++) {
      covered += legs[i];
      if (covered / total > _progress) ahead.add(_route[i + 1]);
    }
    final line = {
      'type': 'Feature',
      'properties': <String, dynamic>{},
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          for (final p in ahead) [p.longitude, p.latitude],
        ],
      },
    };
    if (map.markers.containsKey('truck') && _phase != _Phase.pick) {
      try {
        await map.setGeoJsonData('route', line);
      } on StateError {
        await map.addGeoJson(
          'route',
          line,
          options: const MapelevenGeoJsonOptions(color: brand, lineWidth: 5, fillOpacity: 0),
        );
      }
    }
  }

  Future<void> _reset() async {
    _timer?.cancel();
    await _map?.removeMarker('truck');
    await _map?.removeMarker('home');
    await _map?.removeGeoJson('route');
    setState(() {
      _phase = _Phase.pick;
      _progress = 0;
    });
    await _map?.flyTo(_pin, zoom: 15);
  }

  @override
  Widget build(BuildContext context) {
    final inZone = _inZone(_pin);
    return ListenableBuilder(
      listenable: widget.state,
      // The card sits under the map so the OSM attribution stays visible.
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: MapelevenMap(
                    provider: provider,
                    language: widget.state.language,
                    theme: widget.state.theme,
                    imagery: widget.state.activeImagery,
                    initialCenter: _pin,
                    initialZoom: 15,
                    compassEnabled: false,
                    onMapReady: _onMapReady,
                    onCameraIdle: _onCameraIdle,
                  ),
                ),
                // Fixed centre pin: the map moves underneath it.
                if (_phase == _Phase.pick)
                  const IgnorePointer(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 44),
                        child: Icon(
                          Icons.location_on,
                          size: 48,
                          color: brand,
                          shadows: [Shadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3))],
                        ),
                      ),
                    ),
                  ),
                SafeArea(
                  child: Align(alignment: Alignment.topCenter, child: _banner()),
                ),
              ],
            ),
          ),
          if (_phase == _Phase.pick) _pickCard(inZone) else _trackingCard(),
        ],
      ),
    );
  }

  Widget _banner() => Container(
    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7E6),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFF6D28B)),
    ),
    child: Row(
      children: [
        const Icon(Icons.science_outlined, size: 18, color: Color(0xFF92400E)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(s.simulated, style: const TextStyle(fontSize: 12, color: Color(0xFF92400E))),
        ),
      ],
    ),
  );

  Widget _pickCard(bool inZone) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 6,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.deliverTo, style: text.labelLarge?.copyWith(color: Colors.black54)),
            const SizedBox(height: 4),
            Text(
              _resolving ? s.locating : (_address ?? s.movePin),
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  inZone ? Icons.check_circle : Icons.error_outline,
                  size: 18,
                  color: inZone ? brand : Colors.red.shade700,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    inZone ? s.inZone : s.outOfZone,
                    style: TextStyle(color: inZone ? brand : Colors.red.shade700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(s.movePin, style: text.bodySmall?.copyWith(color: Colors.black45)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: inZone && !_resolving ? _confirm : null,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: Text(s.confirmAddress),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trackingCard() {
    final text = Theme.of(context).textTheme;
    final arrived = _phase == _Phase.arrived;
    final km = _remainingKm;
    final eta = math.max(1, (km / _speedKmh * 60).round());
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 6,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: accent,
                  child: Icon(arrived ? Icons.done : Icons.local_shipping, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        arrived ? s.arrived : s.onTheWay,
                        style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (!arrived)
                        Text(s.driverAway(s.km(km), s.minutes(eta)), style: text.bodyMedium?.copyWith(color: brand)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: _progress, minHeight: 6),
            ),
            const SizedBox(height: 10),
            Text(s.nearest(_distributor), style: text.bodySmall?.copyWith(color: Colors.black54)),
            if (_address != null)
              Text(
                _address!,
                style: text.bodySmall?.copyWith(color: Colors.black54),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (arrived) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _reset,
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                child: Text(s.newOrder),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
