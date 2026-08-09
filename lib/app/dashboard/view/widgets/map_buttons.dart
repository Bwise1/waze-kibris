import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

/// Circular floating control on the map — menu, chat, recenter, report.
///
/// All four share one size and shape so they read as a single family; the
/// default FloatingActionButton is 56pt with a squircle shape, which made
/// the recenter/report pair noticeably larger than the menu and chat
/// buttons opposite them.
class MapCircleButton extends StatelessWidget {
  const MapCircleButton({
    required this.icon,
    required this.onTap,
    this.iconColor = Colors.black87,
    this.backgroundColor = Colors.white,
    super.key,
  });

  /// Matches the menu button: 22pt icon + 10pt padding = 42pt.
  static const double diameter = 42;
  static const double iconSize = 22;

  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all((diameter - iconSize) / 2),
          child: Icon(icon, color: iconColor, size: iconSize),
        ),
      ),
    );
  }
}

/// Compass matching the other floating map controls. Rotates with the map
/// and snaps the map back to north when tapped, like Google Maps.
class MapCompassButton extends StatelessWidget {
  const MapCompassButton({required this.bearing, required this.onTap, super.key});

  final double bearing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: MapCircleButton.diameter,
          height: MapCircleButton.diameter,
          child: Center(
            child: Transform.rotate(
              // Map bearing is clockwise; the needle turns the other way to
              // keep pointing at true north.
              angle: -bearing * math.pi / 180,
              child: Icon(
                Icons.navigation,
                size: MapCircleButton.iconSize,
                color: styles.theme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
