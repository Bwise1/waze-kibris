import 'package:flutter/material.dart';
import 'package:waze_kibris/core/models/directions/mapbox_directions_response.dart';
import 'package:waze_kibris/core/models/navigation/travel_mode.dart';
import 'package:waze_kibris/app/dashboard/view/mapbox_navigation_utils.dart';
import 'package:waze_kibris/app/dashboard/view/lane_arrow_widget.dart';
import 'package:waze_kibris/app/dashboard/bloc/navigation_bloc.dart';

import 'package:waze_kibris/app/dashboard/services/enhanced_navigation_controller.dart';

class ManeuverBanner extends StatelessWidget {
  final MapboxStep step;
  final double distanceRemaining;
  final NavigationBloc? navigationBloc;
  final EnhancedNavigationController? navigationController;
  final MapboxStep? nextStep; // Next-next instruction preview
  final TravelMode mode;

  const ManeuverBanner({
    super.key,
    required this.step,
    required this.distanceRemaining,
    this.navigationBloc,
    this.navigationController,
    this.nextStep,
    this.mode = TravelMode.drive,
  });

  MapboxBannerInstruction? get _currentBanner {
    // Find the appropriate banner based on distance remaining
    for (final banner in step.bannerInstructions) {
      if (distanceRemaining >= banner.distanceAlongGeometry) {
        return banner;
      }
    }
    return step.bannerInstructions.isNotEmpty
        ? step.bannerInstructions.first
        : null;
  }

  bool get _isVoiceEnabled {
    if (navigationBloc != null) return navigationBloc!.isVoiceEnabled;
    if (navigationController != null)
      return navigationController!.isVoiceEnabled;
    return false;
  }

  Future<void> _speakCurrentInstruction() async {
    if (navigationBloc != null) {
      await navigationBloc!.speakCurrentInstruction();
    } else if (navigationController != null) {
      await navigationController!.speakCurrentInstruction();
    }
  }

  @override
  Widget build(BuildContext context) {
    final maneuver = step.maneuver;
    final currentBanner = _currentBanner;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      margin: const EdgeInsets.fromLTRB(12, 44, 12, 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main instruction row: large maneuver badge + distance + street.
            Row(
              children: [
                _buildManeuverIcon(maneuver),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Distance — big and bold, the driver's primary anchor.
                      Text(
                        MapboxNavigationUtils.formatDistance(distanceRemaining),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Street/instruction — the "onto East Homestead Road" bit.
                      Text(
                        currentBanner?.primary.text ?? maneuver.instruction,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isVoiceEnabled ? Icons.volume_up : Icons.volume_off,
                    color: _isVoiceEnabled
                        ? const Color(0xFFFF0000)
                        : Colors.grey,
                    size: 22,
                  ),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: () async {
                    await _speakCurrentInstruction();
                  },
                ),
              ],
            ),

            // Enhanced info row (highway ref, exit number, destinations)
            if (_hasEnhancedInfo())
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 58),
                child: _buildEnhancedInfo(),
              ),

            // "Then" preview of the next-next instruction.
            if (nextStep != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _buildNextStepPreview(),
              ),
          ],
        ),
      ),
    );
  }

  /// Maneuver arrow — same native chevron shape used on the route line, but
  /// larger and in black. Matches the reference (Google Maps / native Mapbox
  /// nav) which shows a clean outlined black arrow with no coloured badge.
  /// The badge/circle look was too heavy and drew attention away from the
  /// distance and street name, which are what the driver actually needs.
  Widget _buildManeuverIcon(MapboxManeuver maneuver) {
    final indication = _modifierToIndication(maneuver.modifier, maneuver.type);
    final isRoundabout =
        maneuver.type == 'roundabout' || maneuver.type == 'rotary';

    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          LaneArrowWidget(
            indications: [indication],
            primaryColor: Colors.black,
            secondaryColor: Colors.black38,
            size: 44,
          ),
          if (isRoundabout && maneuver.exit != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0000),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${maneuver.exit}',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Map Mapbox's maneuver `modifier` string to the LaneArrowPainter's
  /// indication token so we can reuse the same chevron shape.
  String _modifierToIndication(String modifier, String type) {
    switch (modifier.toLowerCase()) {
      case 'left':
        return 'left';
      case 'right':
        return 'right';
      case 'sharp left':
      case 'sharp_left':
        return 'sharp_left';
      case 'sharp right':
      case 'sharp_right':
        return 'sharp_right';
      case 'slight left':
      case 'slight_left':
        return 'slight_left';
      case 'slight right':
      case 'slight_right':
        return 'slight_right';
      case 'uturn':
      case 'u-turn':
        return 'uturn';
      case 'straight':
      default:
        return 'straight';
    }
  }

  bool _hasEnhancedInfo() {
    return step.ref != null || step.destinations != null || step.exits != null;
  }

  Widget _buildEnhancedInfo() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        // Highway/Road reference (A1, M25, I-95)
        if (step.ref != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              step.ref!,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),

        // Exit numbers (Exit 42A)
        if (step.exits != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              step.exits!,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),

        // Destinations (Airport, City Center)
        if (step.destinations != null)
          Flexible(
            child: Text(
              'Towards: ${step.destinations}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  Widget _buildNextStepPreview() {
    if (nextStep == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // "Then" label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFF0000),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'THEN',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Next maneuver icon — same black arrow style as the main icon
          LaneArrowWidget(
            indications: [
              _modifierToIndication(
                nextStep!.maneuver.modifier,
                nextStep!.maneuver.type,
              ),
            ],
            primaryColor: Colors.black,
            secondaryColor: Colors.black38,
            size: 20,
          ),
          const SizedBox(width: 6),

          // Next instruction text (single line)
          Expanded(
            child: Text(
              nextStep!.maneuver.instruction,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(width: 6),

          // Distance to next step
          Text(
            MapboxNavigationUtils.formatDistance(step.distance),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
