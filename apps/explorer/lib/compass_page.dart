import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapeleven/mapeleven.dart';

import 'app_state.dart';
import 'main.dart';
import 'strings.dart';

/// Points to a place with the phone's compass and gives the straight-line
/// distance. Needs neither internet nor GPS: the start is live GPS when it
/// works, else the position the user set by hand, else the map centre.
class CompassPage extends StatefulWidget {
  const CompassPage({super.key, required this.state, required this.target, required this.mapCentre});
  final AppState state;
  final SavedPlace target;
  final LatLng mapCentre;

  @override
  State<CompassPage> createState() => _CompassPageState();
}

class _CompassPageState extends State<CompassPage> {
  StreamSubscription<CompassEvent>? _compass;
  StreamSubscription<Position>? _gpsSub;
  double? _heading;
  double? _accuracy;
  bool _hasCompass = !kIsWeb;
  LatLng? _gps;

  S get s => S(widget.state.language);

  @override
  void initState() {
    super.initState();
    final events = kIsWeb ? null : FlutterCompass.events;
    if (events == null) {
      _hasCompass = false;
    } else {
      _compass = events.listen(
        (e) {
          if (e.heading == null) return setState(() => _hasCompass = false);
          setState(() {
            _heading = e.heading;
            _accuracy = e.accuracy;
          });
        },
        onError: (_) => setState(() => _hasCompass = false),
      );
    }
    // Live GPS only when the user has not overridden it by hand.
    if (widget.state.manualHere == null) unawaited(_followGps());
  }

  Future<void> _followGps() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm != LocationPermission.always && perm != LocationPermission.whileInUse) return;
      _gpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
      ).listen((p) => setState(() => _gps = LatLng(p.latitude, p.longitude)), onError: (_) {});
    } catch (_) {
      // No GPS: the hand-set position or the map centre is used.
    }
  }

  @override
  void dispose() {
    _compass?.cancel();
    _gpsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final manual = state.manualHere;
    final LatLng from;
    final String fromText;
    if (manual != null) {
      from = manual.position;
      fromText = s.fromManual(manual.name.isEmpty ? s.pickedPoint : manual.name);
    } else if (_gps != null || state.myLocation != null) {
      from = _gps ?? state.myLocation!;
      fromText = s.fromGps;
    } else {
      from = widget.mapCentre;
      fromText = s.fromCentre;
    }
    final to = widget.target.position;
    final dist = distanceKm(from, to);
    final toward = bearing(from, to);
    final heading = _hasCompass ? _heading : null;
    // Arrow angle on screen: relative to where the phone points, or to north.
    final arrow = heading == null ? toward : toward - heading;
    final rel = ((arrow % 360) + 360) % 360;
    final facing = heading != null && (rel < 10 || rel > 350);
    final text = Theme.of(context).textTheme;
    final dir = s.cardinal(toward);
    final deg = toward.round() % 360;
    final calibrate = heading != null && (_accuracy == null || _accuracy! > 25 || _accuracy! < 0);

    return Scaffold(
      appBar: AppBar(title: Text(s.compass)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Text(
              widget.target.name.isEmpty ? s.droppedPin : widget.target.name,
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              s.straightLine(s.km(dist)),
              style: text.titleMedium?.copyWith(color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Center(
              child: SizedBox.square(
                dimension: math.min(320, MediaQuery.sizeOf(context).width - 48),
                // The dial is drawn left-to-right in both languages: east stays on the right.
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        painter: _DialPainter(
                          northAngle: heading == null ? 0 : -heading,
                          arrowAngle: arrow,
                          arrowColor: facing ? const Color(0xFF16A34A) : brand,
                        ),
                      ),
                      // N, E, S, W as widgets (not canvas text) so web fonts that load late still show.
                      for (var k = 0; k < 4; k++)
                        Align(
                          alignment: _onRing((heading == null ? 0 : -heading) + k * 90, 0.72),
                          child: Text(
                            s.compassPoints[k],
                            style: TextStyle(
                              fontSize: k == 0 ? 24 : 19,
                              fontWeight: FontWeight.w700,
                              color: k == 0 ? const Color(0xFFDC2626) : const Color(0xFF334155),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              s.head(dir, deg),
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (heading != null)
              Text(
                facing ? s.facingIt : s.turnHint,
                style: text.bodyLarge?.copyWith(color: facing ? const Color(0xFF16A34A) : null),
                textAlign: TextAlign.center,
              )
            else
              Text(s.noCompass(dir, deg), style: text.bodyLarge, textAlign: TextAlign.center),
            if (calibrate) ...[
              const SizedBox(height: 12),
              _Note(icon: Icons.screen_rotation_alt, text: s.calibrate, color: const Color(0xFFB45309)),
            ],
            const SizedBox(height: 20),
            _Note(icon: manual != null ? Icons.person_pin_circle_outlined : Icons.my_location, text: fromText),
            const SizedBox(height: 8),
            _Note(icon: Icons.info_outline, text: s.compassNote),
          ],
        ),
      ),
    );
  }
}

/// Where a point at [deg] (clockwise from screen-up) on a ring of [radius] (0..1) sits in a square.
Alignment _onRing(double deg, double radius) {
  final a = deg * math.pi / 180;
  return Alignment(math.sin(a) * radius, -math.cos(a) * radius);
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color ?? Colors.black54),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: color ?? Colors.black54))),
      ],
    );
  }
}

/// Compass dial: a ring with N/E/S/W that turns with the phone, and an arrow to the target.
class _DialPainter extends CustomPainter {
  _DialPainter({required this.northAngle, required this.arrowAngle, required this.arrowColor});

  /// Degrees, clockwise: where north is on screen.
  final double northAngle;

  /// Degrees, clockwise from screen-up: where the target is.
  final double arrowAngle;
  final Color arrowColor;

  static double _rad(double d) => d * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFF8FAFC));
    canvas.drawCircle(c, r - 1, Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);

    // Ticks every 10°, longer every 30°.
    for (var d = 0; d < 360; d += 10) {
      final a = _rad(northAngle + d);
      final long = d % 30 == 0;
      final outer = Offset(c.dx + math.sin(a) * (r - 6), c.dy - math.cos(a) * (r - 6));
      final inner = Offset(c.dx + math.sin(a) * (r - (long ? 20 : 13)), c.dy - math.cos(a) * (r - (long ? 20 : 13)));
      canvas.drawLine(inner, outer, Paint()
        ..color = long ? const Color(0xFF475569) : const Color(0xFFA0AEC0)
        ..strokeWidth = long ? 2 : 1);
    }

    // Arrow to the target.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(_rad(arrowAngle));
    final len = r * 0.58;
    final path = Path()
      ..moveTo(0, -len)
      ..lineTo(len * 0.32, -len * 0.42)
      ..lineTo(len * 0.11, -len * 0.42)
      ..lineTo(len * 0.11, len * 0.55)
      ..lineTo(-len * 0.11, len * 0.55)
      ..lineTo(-len * 0.11, -len * 0.42)
      ..lineTo(-len * 0.32, -len * 0.42)
      ..close();
    canvas.drawShadow(path, Colors.black, 3, false);
    canvas.drawPath(path, Paint()..color = arrowColor);
    canvas.restore();
    canvas.drawCircle(c, 7, Paint()..color = const Color(0xFF0F172A));
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.northAngle != northAngle || old.arrowAngle != arrowAngle || old.arrowColor != arrowColor;
}
