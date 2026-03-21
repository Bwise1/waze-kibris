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

/// Radians for each indication (0 = up, positive = right).
double _angleRadiansForIndication(String indication) {
  switch (indication.toLowerCase()) {
    case 'straight':
      return 0;
    case 'slight_right':
      return math.pi / 4;
    case 'right':
      return math.pi / 2;
    case 'sharp_right':
      return 3 * math.pi / 4;
    case 'slight_left':
      return -math.pi / 4;
    case 'left':
      return -math.pi / 2;
    case 'sharp_left':
      return -3 * math.pi / 4;
    case 'uturn':
      return math.pi;
    default:
      return 0;
  }
}

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

/// Paints a single lane's arrows in the same style as native Mapbox iOS (LanesStyleKit)
/// and Android (lane vector drawables): 1–3 arrow shapes with primary/secondary color.
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
    final padding = size.shortestSide * 0.15;
    final usableWidth = size.width - 2 * padding;
    final usableHeight = size.height - 2 * padding;

    // Draw up to 3 arrows in a row (or column if very narrow)
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
      final cellSize = math.min(cellW, cellH) * 0.85;
      final color = (highlightedIndex == null || highlightedIndex == i)
          ? primaryColor
          : secondaryColor;
      _drawArrow(
        canvas,
        center: Offset(cx, cy),
        size: cellSize,
        indication: _sorted[i],
        color: color,
      );
    }
  }

  void _drawArrow(
    Canvas canvas, {
    required Offset center,
    required double size,
    required String indication,
    required Color color,
  }) {
    final angle = _angleRadiansForIndication(indication);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = indication.toLowerCase() == 'uturn'
        ? _uturnPath()
        : _chevronPath();
    path.transform(
      (Matrix4.identity()..scale(size / 24.0)).storage,
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  /// Chevron arrow (point up in default orientation), ~24x24 unit size.
  static Path _chevronPath() {
    const u = 12.0;
    return Path()
      ..moveTo(0, -u)   // tip
      ..lineTo(u * 0.6, u * 0.5)
      ..lineTo(u * 0.25, u * 0.5)
      ..lineTo(u * 0.25, u)
      ..lineTo(-u * 0.25, u)
      ..lineTo(-u * 0.25, u * 0.5)
      ..lineTo(-u * 0.6, u * 0.5)
      ..close();
  }

  /// U-turn: 180° arrow (semicircle with arrowhead).
  static Path _uturnPath() {
    const u = 12.0;
    final path = Path();
    path.moveTo(u * 0.5, -u);
    path.lineTo(u * 0.2, u * 0.3);
    path.quadraticBezierTo(-u * 0.3, u * 0.3, -u * 0.3, -u * 0.5);
    path.quadraticBezierTo(-u * 0.3, -u, u * 0.5, -u);
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant LaneArrowPainter oldDelegate) {
    return oldDelegate.indications != indications ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.highlightedIndex != highlightedIndex;
  }
}
