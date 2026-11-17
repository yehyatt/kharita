import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// An image that markers can use. Register it once with
/// [MapelevenController.registerIcon], then pass its [name] to `addMarker`.
class MapelevenIcon {
  const MapelevenIcon(this.name, this.png, {this.pixelRatio = 3});

  /// Id used by markers (`addMarker(..., icon: name)`).
  final String name;

  /// PNG bytes, drawn at [pixelRatio] (3 means a 120 px image shows as 40 pt).
  final Uint8List png;
  final double pixelRatio;

  /// Paints a Material or Cupertino [icon] on a filled disc, the usual look for
  /// vehicles and category pins. [size] is in logical pixels.
  static Future<MapelevenIcon> fromIconData(
    String name,
    IconData icon, {
    Color color = const Color(0xFFFFFFFF),
    Color background = const Color(0xFF0066FF),
    Color ring = const Color(0xFFFFFFFF),
    double size = 40,
    double pixelRatio = 3,
  }) async {
    final px = size * pixelRatio;
    final center = Offset(px / 2, px / 2);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawCircle(center, px * 0.48, Paint()..color = ring);
    canvas.drawCircle(center, px * 0.41, Paint()..color = background);
    final painter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(fontSize: px * 0.5, fontFamily: icon.fontFamily, package: icon.fontPackage, color: color),
      )
      ..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
    final image = await recorder.endRecording().toImage(px.round(), px.round());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return MapelevenIcon(name, data!.buffer.asUint8List(), pixelRatio: pixelRatio);
  }

  /// A teardrop pin with [icon] inside, anchored at its tip (use
  /// `anchor: MapelevenAnchor.bottom` when adding the marker).
  static Future<MapelevenIcon> pin(
    String name, {
    IconData? icon,
    Color color = const Color(0xFF0066FF),
    Color iconColor = const Color(0xFFFFFFFF),
    double size = 44,
    double pixelRatio = 3,
  }) async {
    final w = size * pixelRatio * 0.75;
    final h = size * pixelRatio;
    final r = w / 2;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final path = Path()
      ..moveTo(r, h)
      ..quadraticBezierTo(r - r * 0.25, h - r * 0.55, r * 0.12, r * 1.45)
      ..arcTo(Rect.fromCircle(center: Offset(r, r), radius: r * 0.98), 2.55, 4.31, false)
      ..quadraticBezierTo(r + r * 0.25, h - r * 0.55, r, h)
      ..close();
    canvas.drawShadow(path, const Color(0x66000000), 3 * pixelRatio / 3, false);
    canvas.drawPath(path, Paint()..color = color);
    if (icon != null) {
      final painter = TextPainter(textDirection: TextDirection.ltr)
        ..text = TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: r * 1.05,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: iconColor,
          ),
        )
        ..layout();
      painter.paint(canvas, Offset(r - painter.width / 2, r - painter.height / 2));
    } else {
      canvas.drawCircle(Offset(r, r), r * 0.36, Paint()..color = iconColor);
    }
    final image = await recorder.endRecording().toImage(w.round(), h.round());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return MapelevenIcon(name, data!.buffer.asUint8List(), pixelRatio: pixelRatio);
  }
}

/// Which point of a marker's icon sits on its coordinate.
enum MapelevenAnchor {
  center,

  /// For pins: the tip touches the coordinate.
  bottom,
}
