import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:waze_kibris/core/services/nav_puck_preference.dart';

/// Renders top-down vehicle icons for the navigation puck at runtime.
///
/// The vehicles point "up" — the Mapbox LocationPuck2D rotates the image to
/// the travel course, so up == direction of travel. Each icon gets a soft
/// drop shadow and a white outline so it stays legible on any map style,
/// matching how the native chevron is outlined.
class PuckIconFactory {
  PuckIconFactory._();

  static final Map<NavPuckStyle, Uint8List> _cache = {};
  static final Map<NavPuckMode, Uint8List> _modeCache = {};

  /// Puck for walking/cycling.
  ///
  /// Cycling gets proper top-down artwork like the vehicles — a bike has a
  /// real overhead silhouette. Walking doesn't, so it follows the
  /// Google/Apple convention of a marker with an icon.
  static Future<Uint8List?> renderMode(NavPuckMode mode,
      {double size = 128}) async {
    if (mode == NavPuckMode.vehicle) return null;
    final cached = _modeCache[mode];
    if (cached != null) return cached;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    if (mode == NavPuckMode.cycle) {
      _paintBike(canvas, size);
      final picture = recorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) return null;
      final bytes = data.buffer.asUint8List();
      _modeCache[mode] = bytes;
      return bytes;
    }

    final k = size / 128;
    canvas.scale(k);

    // Walking only — cycling returned above with its own artwork.
    const cx = 64.0;
    const centre = Offset(cx, cx);
    const radius = 34.0;
    const colour = Color(0xFF2E7D32); // walking green

    // Heading nose, so the puck still shows which way you're facing.
    final nose = Path()
      ..moveTo(cx - 13, 30)
      ..lineTo(cx, 8)
      ..lineTo(cx + 13, 30)
      ..close();
    canvas.drawPath(nose, Paint()..color = colour);

    canvas.drawCircle(
      centre.translate(0, 3),
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(centre, radius, Paint()..color = Colors.white);
    canvas.drawCircle(centre, radius - 4, Paint()..color = colour);

    const icon = Icons.directions_walk;
    final painter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 38,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
        ),
      )
      ..layout();
    painter.paint(
      canvas,
      centre - Offset(painter.width / 2, painter.height / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) return null;
    final bytes = byteData.buffer.asUint8List();
    _modeCache[mode] = bytes;
    return bytes;
  }

  /// PNG bytes for [style] at [size]×[size] px (128 matches the 4.0x
  /// resolution of the stock arrow asset).
  static Future<Uint8List?> render(NavPuckStyle style,
      {double size = 128}) async {
    if (style == NavPuckStyle.arrow) {
      return null; // uses the bundled asset, not a generated image
    }
    final cached = _cache[style];
    if (cached != null) return cached;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    switch (style) {
      case NavPuckStyle.arrow:
        break;
      case NavPuckStyle.car:
        _paintCar(canvas, size);
      case NavPuckStyle.bike:
        _paintBike(canvas, size);
      case NavPuckStyle.bus:
        _paintBus(canvas, size);
      case NavPuckStyle.truck:
        _paintTruck(canvas, size);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) return null;
    final bytes = byteData.buffer.asUint8List();
    _cache[style] = bytes;
    return bytes;
  }

  // ---- shared helpers -----------------------------------------------------

  static const Color _glass = Color(0xFF26323E);

  static void _shadow(Canvas canvas, double cx, double top, double bottom,
      double halfWidth) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawRRect(
      RRect.fromLTRBR(cx - halfWidth, top + 6, cx + halfWidth, bottom + 6,
          Radius.circular(halfWidth)),
      paint,
    );
  }

  /// White outline + vertically-lit body fill.
  static void _body(Canvas canvas, RRect shape, Color color) {
    canvas.drawRRect(shape.inflate(5), Paint()..color = Colors.white);
    final rect = shape.outerRect;
    canvas.drawRRect(
      shape,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(color, Colors.white, 0.18)!,
            color,
            Color.lerp(color, Colors.black, 0.22)!,
          ],
        ).createShader(rect),
    );
  }

  static void _glassRect(Canvas canvas, double l, double t, double r,
      double b, double radius) {
    canvas.drawRRect(
      RRect.fromLTRBR(l, t, r, b, Radius.circular(radius)),
      Paint()..color = _glass,
    );
  }

  // ---- vehicles (canvas is size×size, vehicle centered, nose up) ----------

  /// Top-down cyclist: two wheels, frame, and the rider's shoulders and
  /// helmet seen from above. A bike has a real overhead silhouette, so it
  /// gets proper artwork rather than a disc-with-glyph.
  static void _paintBike(Canvas canvas, double s) {
    final k = s / 128;
    canvas.scale(k);
    const cx = 64.0;
    _shadow(canvas, cx, 26, 104, 15);

    const tyre = Color(0xFF2B3440);
    final tyrePaint = Paint()..color = tyre;

    // Front and rear wheels (narrow from overhead).
    canvas.drawRRect(
      RRect.fromLTRBR(cx - 4, 24, cx + 4, 52, const Radius.circular(4)),
      tyrePaint,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(cx - 4, 78, cx + 4, 106, const Radius.circular(4)),
      tyrePaint,
    );

    // Frame connecting the wheels.
    canvas.drawRRect(
      RRect.fromLTRBR(cx - 2.5, 46, cx + 2.5, 84, const Radius.circular(2)),
      Paint()..color = const Color(0xFF7A8797),
    );

    // Handlebars.
    canvas.drawRRect(
      RRect.fromLTRBR(cx - 20, 48, cx + 20, 55, const Radius.circular(3.5)),
      Paint()..color = const Color(0xFF44505F),
    );

    // Rider: shoulders then helmet, both outlined in white so the shape
    // stays legible on any map style.
    const rider = Color(0xFF1565C0);
    final shoulders = RRect.fromLTRBR(
        cx - 15, 54, cx + 15, 82, const Radius.circular(13));
    canvas.drawRRect(shoulders.inflate(3.5), Paint()..color = Colors.white);
    canvas.drawRRect(shoulders, Paint()..color = rider);

    canvas.drawCircle(const Offset(cx, 62), 13.5, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(cx, 62), 10.5, Paint()..color = rider);
    // Helmet highlight, so the front of the rider is readable.
    canvas.drawCircle(
      const Offset(cx, 58.5),
      6,
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  static void _paintCar(Canvas canvas, double s) {
    final k = s / 128; // all coordinates below are in 128-space
    canvas.scale(k);
    const cx = 64.0;
    _shadow(canvas, cx, 20, 110, 27);

    final body =
        RRect.fromLTRBAndCorners(cx - 26, 18, cx + 26, 112,
            topLeft: const Radius.circular(26),
            topRight: const Radius.circular(26),
            bottomLeft: const Radius.circular(18),
            bottomRight: const Radius.circular(18));
    _body(canvas, body, const Color(0xFFE53935));

    // Side mirrors
    final mirror = Paint()..color = const Color(0xFFB71C1C);
    canvas.drawRRect(
        RRect.fromLTRBR(cx - 33, 42, cx - 25, 50, const Radius.circular(3)),
        mirror);
    canvas.drawRRect(
        RRect.fromLTRBR(cx + 25, 42, cx + 33, 50, const Radius.circular(3)),
        mirror);

    // Windshield, roof highlight, rear window
    _glassRect(canvas, cx - 19, 36, cx + 19, 54, 9);
    canvas.drawRRect(
      RRect.fromLTRBR(cx - 17, 58, cx + 17, 86, const Radius.circular(8)),
      Paint()..color = Colors.white.withValues(alpha: 0.14),
    );
    _glassRect(canvas, cx - 17, 90, cx + 17, 102, 7);
  }

  static void _paintBus(Canvas canvas, double s) {
    final k = s / 128;
    canvas.scale(k);
    const cx = 64.0;
    _shadow(canvas, cx, 14, 116, 29);

    final body = RRect.fromLTRBR(cx - 28, 12, cx + 28, 116,
        const Radius.circular(14));
    _body(canvas, body, const Color(0xFFFB8C00));

    // Windshield band
    _glassRect(canvas, cx - 22, 22, cx + 22, 38, 7);
    // Passenger windows (three rows)
    for (final top in const [48.0, 66.0, 84.0]) {
      _glassRect(canvas, cx - 22, top, cx - 6, top + 12, 4);
      _glassRect(canvas, cx + 6, top, cx + 22, top + 12, 4);
    }
    // Roof walkway stripe
    canvas.drawRRect(
      RRect.fromLTRBR(cx - 3, 46, cx + 3, 100, const Radius.circular(3)),
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  static void _paintTruck(Canvas canvas, double s) {
    final k = s / 128;
    canvas.scale(k);
    const cx = 64.0;
    _shadow(canvas, cx, 12, 118, 29);

    // Trailer (drawn first — sits behind the cab joint)
    final trailer = RRect.fromLTRBR(cx - 27, 50, cx + 27, 118,
        const Radius.circular(10));
    _body(canvas, trailer, const Color(0xFFB0BEC5));
    // Trailer roof ribs
    final rib = Paint()
      ..color = Colors.black.withValues(alpha: 0.10)
      ..strokeWidth = 3;
    for (final y in const [66.0, 82.0, 98.0]) {
      canvas.drawLine(Offset(cx - 22, y), Offset(cx + 22, y), rib);
    }

    // Cab
    final cab = RRect.fromLTRBAndCorners(cx - 24, 12, cx + 24, 46,
        topLeft: const Radius.circular(16),
        topRight: const Radius.circular(16),
        bottomLeft: const Radius.circular(8),
        bottomRight: const Radius.circular(8));
    _body(canvas, cab, const Color(0xFF1E88E5));
    _glassRect(canvas, cx - 17, 20, cx + 17, 34, 7);
  }
}

/// Paints the same vehicles for in-app previews (settings page).
class PuckPreviewPainter extends CustomPainter {
  PuckPreviewPainter(this.style);
  final NavPuckStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    switch (style) {
      case NavPuckStyle.arrow:
        break; // previewed with the bundled asset image instead
      case NavPuckStyle.car:
        PuckIconFactory._paintCar(canvas, s);
      case NavPuckStyle.bike:
        PuckIconFactory._paintBike(canvas, s);
      case NavPuckStyle.bus:
        PuckIconFactory._paintBus(canvas, s);
      case NavPuckStyle.truck:
        PuckIconFactory._paintTruck(canvas, s);
    }
  }

  @override
  bool shouldRepaint(PuckPreviewPainter oldDelegate) =>
      oldDelegate.style != style;
}
