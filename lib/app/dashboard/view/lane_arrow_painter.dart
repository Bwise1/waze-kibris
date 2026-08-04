import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Mapbox Directions API lane indication values (lowercase).
const List<String> kLaneIndicationOrder = [
  'sharp_left',
  'left',
  'slight_left',
  'straight',
  'slight_right',
  'right',
  'sharp_right',
  'uturn',
];

/// Sorts and deduplicates indications in display order (left → straight → right → uturn).
List<String> sortIndicationsForDisplay(List<String> indications) {
  final seen = <String>{};
  final result = <String>[];
  for (final key in kLaneIndicationOrder) {
    if (indications.any((i) => i.toLowerCase() == key) && seen.add(key)) {
      result.add(key);
    }
  }
  return result;
}

/// Paints a single lane's arrow(s) as an **L-shaped stroke** — a shaft
/// coming up from the bottom, bending at the top toward the turn direction,
/// with a filled triangle arrowhead at the tip.
///
/// This is the Google Maps / Apple Maps convention: the shaft represents the
/// road you're currently on, and the horizontal top with the arrowhead shows
/// where the turn goes. Much more expressive than a plain chevron rotated in
/// place.
class LaneArrowPainter extends CustomPainter {
  LaneArrowPainter({
    required this.indications,
    required this.primaryColor,
    required this.secondaryColor,
    this.highlightedIndex,
  }) : _sorted = sortIndicationsForDisplay(indications).take(3).toList();

  final List<String> indications;
  final Color primaryColor;
  final Color secondaryColor;
  final int? highlightedIndex;

  final List<String> _sorted;

  @override
  void paint(Canvas canvas, Size size) {
    if (_sorted.isEmpty) return;

    final count = _sorted.length;
    final padding = size.shortestSide * 0.1;
    final usableWidth = size.width - 2 * padding;
    final usableHeight = size.height - 2 * padding;

    // Layout multiple lane arrows side-by-side.
    final bool horizontal = size.width >= size.height;
    final double cellW = horizontal ? (usableWidth / count) : usableWidth;
    final double cellH = horizontal ? usableHeight : (usableHeight / count);

    for (int i = 0; i < count; i++) {
      final cx = horizontal
          ? padding + cellW * (i + 0.5)
          : padding + usableWidth / 2;
      final cy = horizontal
          ? padding + usableHeight / 2
          : padding + cellH * (i + 0.5);
      final cellSize = math.min(cellW, cellH);
      final color = (highlightedIndex == null || highlightedIndex == i)
          ? primaryColor
          : secondaryColor;
      _drawTurnArrow(
        canvas,
        center: Offset(cx, cy),
        size: cellSize,
        indication: _sorted[i],
        color: color,
      );
    }
  }

  /// Draws one turn arrow of [size] px, centred on [center].
  void _drawTurnArrow(
    Canvas canvas, {
    required Offset center,
    required double size,
    required String indication,
    required Color color,
  }) {
    final ind = indication.toLowerCase();

    // U-turn is a special shape — semicircle with an arrowhead on the way back.
    if (ind == 'uturn') {
      _drawUturn(canvas, center, size, color);
      return;
    }

    // Straight: just a vertical shaft with arrowhead at top.
    if (ind == 'straight') {
      _drawStraight(canvas, center, size, color);
      return;
    }

    // Bend angles from vertical: right = -90° (turn right), left = +90°
    // (from the shaft-going-up frame, "right turn" bends the shaft
    // clockwise when viewed on screen — but in canvas coords with y-down,
    // that's negative rotation of the horizontal segment). We express each
    // turn as (bendDeg, isLeft) where bendDeg is the angle between the
    // shaft and the outgoing horizontal segment.
    late double bendDeg;
    late bool isLeft;
    switch (ind) {
      case 'slight_left':
        bendDeg = 45;
        isLeft = true;
        break;
      case 'left':
        bendDeg = 90;
        isLeft = true;
        break;
      case 'sharp_left':
        bendDeg = 135;
        isLeft = true;
        break;
      case 'slight_right':
        bendDeg = 45;
        isLeft = false;
        break;
      case 'right':
        bendDeg = 90;
        isLeft = false;
        break;
      case 'sharp_right':
        bendDeg = 135;
        isLeft = false;
        break;
      default:
        _drawStraight(canvas, center, size, color);
        return;
    }

    _drawLShapedTurn(canvas, center, size, color, bendDeg, isLeft);
  }

  /// Straight arrow: vertical shaft with triangular head at the top.
  void _drawStraight(Canvas canvas, Offset center, double size, Color color) {
    final strokeWidth = size * 0.14;
    final halfHeight = size * 0.42;
    final headSize = size * 0.26;

    final shaftPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Shaft: from bottom-center up to just below the head.
    final tipY = center.dy - halfHeight;
    final shaftBottom = Offset(center.dx, center.dy + halfHeight);
    final shaftTop = Offset(center.dx, tipY + headSize * 0.5);
    canvas.drawLine(shaftBottom, shaftTop, shaftPaint);

    // Arrowhead triangle.
    _drawArrowhead(
      canvas,
      tip: Offset(center.dx, tipY),
      bearingRad: 0, // pointing straight up
      size: headSize,
      color: color,
    );
  }

  /// L-shaped turn: shaft up + bend + outgoing segment with arrowhead.
  void _drawLShapedTurn(
    Canvas canvas,
    Offset center,
    double size,
    Color color,
    double bendDeg,
    bool isLeft,
  ) {
    final strokeWidth = size * 0.14;
    final headSize = size * 0.26;

    // Geometry: shaft comes up from bottom to a bend point, then heads off
    // at (bendDeg) from vertical toward the turn direction.
    final shaftBottom = Offset(center.dx, center.dy + size * 0.42);
    // Bend point sits slightly below center so the outgoing segment has
    // room to breathe.
    final bendPoint = Offset(center.dx, center.dy + size * 0.05);

    // Outgoing direction as a unit vector.
    // A "left" turn heads to negative x; a "right" turn to positive x.
    // bendDeg = angle FROM the shaft (which points up = -y).
    // In canvas coords (y-down), rotating (-y) by +θ clockwise on screen:
    //   dx = sin(θ),  dy = -cos(θ) — but for "right" we want +sin, for "left" -sin.
    final rad = bendDeg * math.pi / 180;
    final dx = (isLeft ? -1 : 1) * math.sin(rad);
    final dy = -math.cos(rad);

    // Length of the outgoing segment.
    final outLen = size * 0.42;
    // Tip = end of the outgoing segment, minus half a head so the triangle
    // sits nicely at the tip without overshooting the intended bounds.
    final tip = Offset(
      bendPoint.dx + dx * outLen,
      bendPoint.dy + dy * outLen,
    );
    // Where the stroke ends (just short of the tip to let the triangle sit
    // flush against it).
    final strokeEnd = Offset(
      tip.dx - dx * headSize * 0.55,
      tip.dy - dy * headSize * 0.55,
    );

    // Draw the L using a Path with a rounded corner (quadratic curve at
    // the bend point).
    final path = Path();
    path.moveTo(shaftBottom.dx, shaftBottom.dy);

    // Shaft goes up to slightly before the bend so we can round the corner.
    final cornerRadius = size * 0.14;
    final shaftEndY = bendPoint.dy + cornerRadius;
    path.lineTo(bendPoint.dx, shaftEndY);

    // Rounded corner from vertical to the outgoing direction. Control point
    // is at the bend point itself (creates a natural curved elbow).
    final cornerExit = Offset(
      bendPoint.dx + dx * cornerRadius,
      bendPoint.dy + dy * cornerRadius,
    );
    path.quadraticBezierTo(
      bendPoint.dx, bendPoint.dy, // control point
      cornerExit.dx, cornerExit.dy,
    );

    // Outgoing segment to just before the arrowhead.
    path.lineTo(strokeEnd.dx, strokeEnd.dy);

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    canvas.drawPath(path, strokePaint);

    // Arrowhead pointing along the outgoing direction.
    final bearing = math.atan2(dx, -dy); // 0 = up, +π/2 = right
    _drawArrowhead(
      canvas,
      tip: tip,
      bearingRad: bearing,
      size: headSize,
      color: color,
    );
  }

  /// U-turn: shaft up, tight semicircle, shaft back down on the opposite
  /// side with an arrowhead. Default direction goes to the left (like most
  /// left-hand-drive countries); flip if you need right-hand.
  void _drawUturn(Canvas canvas, Offset center, double size, Color color) {
    final strokeWidth = size * 0.12;
    final headSize = size * 0.24;
    final radius = size * 0.18;

    final rightShaftBottom = Offset(center.dx + radius, center.dy + size * 0.42);
    final rightShaftTop = Offset(center.dx + radius, center.dy - size * 0.05);
    final leftShaftTop = Offset(center.dx - radius, center.dy - size * 0.05);
    final tip = Offset(center.dx - radius, center.dy + size * 0.30);
    final strokeEnd = Offset(tip.dx, tip.dy - headSize * 0.55);

    final path = Path();
    path.moveTo(rightShaftBottom.dx, rightShaftBottom.dy);
    path.lineTo(rightShaftTop.dx, rightShaftTop.dy);
    // Semicircle from right shaft top to left shaft top.
    path.arcToPoint(
      leftShaftTop,
      radius: Radius.circular(radius),
      clockwise: false,
    );
    path.lineTo(strokeEnd.dx, strokeEnd.dy);

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );

    // Arrowhead pointing down (the return shaft goes downward).
    _drawArrowhead(
      canvas,
      tip: tip,
      bearingRad: math.pi, // pointing down
      size: headSize,
      color: color,
    );
  }

  /// Filled triangular arrowhead at [tip], with the triangle pointing in
  /// [bearingRad] direction (0 = up, +π/2 = right, π = down).
  void _drawArrowhead(
    Canvas canvas, {
    required Offset tip,
    required double bearingRad,
    required double size,
    required Color color,
  }) {
    final half = size * 0.5;
    // Triangle in local space, tip at origin, base extending back along -y.
    // Slightly narrower than tall for a sharp, road-sign-style arrowhead.
    final localPath = Path()
      ..moveTo(0, 0)
      ..lineTo(-half * 0.7, half * 1.1)
      ..lineTo(half * 0.7, half * 1.1)
      ..close();

    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(bearingRad);
    canvas.drawPath(
      localPath,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LaneArrowPainter oldDelegate) {
    return oldDelegate.indications != indications ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.highlightedIndex != highlightedIndex;
  }
}
