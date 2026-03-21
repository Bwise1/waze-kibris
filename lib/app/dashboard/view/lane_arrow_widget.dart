import 'package:flutter/material.dart';
import 'package:waze_kibris/app/dashboard/view/lane_arrow_painter.dart';

/// A single lane cell drawn with [LaneArrowPainter] (native-style arrows).
/// Use this in the maneuver banner or on the map; size is fully controllable.
class LaneArrowWidget extends StatelessWidget {
  const LaneArrowWidget({
    super.key,
    required this.indications,
    required this.primaryColor,
    required this.secondaryColor,
    this.highlightedIndex,
    this.size = 32.0,
  });

  final List<String> indications;
  final Color primaryColor;
  final Color secondaryColor;
  /// Which arrow (0-based) to show in primary color; others use secondary. Null = all primary.
  final int? highlightedIndex;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (indications.isEmpty) return SizedBox(width: size, height: size);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: LaneArrowPainter(
          indications: indications,
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
          highlightedIndex: highlightedIndex,
        ),
      ),
    );
  }
}
