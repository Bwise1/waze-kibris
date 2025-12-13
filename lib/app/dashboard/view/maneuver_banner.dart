import 'package:flutter/material.dart';
import 'package:waze_kibris/core/models/directions/mapbox_directions_response.dart';
import 'package:waze_kibris/app/dashboard/view/mapbox_navigation_utils.dart';
import 'package:waze_kibris/app/dashboard/view/lane_guidance_widget.dart';
import 'package:waze_kibris/app/dashboard/bloc/navigation_bloc.dart';

import 'package:waze_kibris/app/dashboard/services/enhanced_navigation_controller.dart';

class ManeuverBanner extends StatelessWidget {
  final MapboxStep step;
  final double distanceRemaining;
  final NavigationBloc? navigationBloc;
  final EnhancedNavigationController? navigationController;
  final MapboxStep? nextStep; // Next-next instruction preview

  const ManeuverBanner({
    super.key,
    required this.step,
    required this.distanceRemaining,
    this.navigationBloc,
    this.navigationController,
    this.nextStep,
  });

  MapboxBannerInstruction? get _currentBanner {
    // Find the appropriate banner based on distance remaining
    for (final banner in step.bannerInstructions) {
      if (distanceRemaining >= banner.distanceAlongGeometry) {
        return banner;
      }
    }
    return step.bannerInstructions.isNotEmpty ? step.bannerInstructions.first : null;
  }

  bool get _isVoiceEnabled {
    if (navigationBloc != null) return navigationBloc!.isVoiceEnabled;
    if (navigationController != null) return navigationController!.isVoiceEnabled;
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 8,
      margin: const EdgeInsets.fromLTRB(16, 44, 16, 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            // Main instruction row
            Row(
              children: [
                // Enhanced maneuver icon
                _buildManeuverIcon(maneuver),
                const SizedBox(width: 16),
                
                // Instruction details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Distance
                      Text(
                        MapboxNavigationUtils.formatDistance(distanceRemaining),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      
                      // Primary instruction (use banner if available, fallback to maneuver)
                      Text(
                        currentBanner?.primary.text ?? maneuver.instruction,
                        style: const TextStyle(fontSize: 16, color: Colors.black),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      // Secondary instruction
                      if (currentBanner?.secondary != null)
                        Text(
                          currentBanner!.secondary!.text,
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      
                      // Road name/reference
                      Text(
                        step.name.isNotEmpty ? step.name : 'Continue',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                // Voice button
                IconButton(
                  icon: Icon(
                    _isVoiceEnabled
                        ? Icons.volume_up
                        : Icons.volume_off,
                    color: _isVoiceEnabled
                        ? Colors.black
                        : Colors.grey,
                  ),
                  onPressed: () async {
                    // Toggle voice and speak current instruction
                    await _speakCurrentInstruction();
                  },
                ),
              ],
            ),
            
            // Enhanced information row
            if (_hasEnhancedInfo())
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _buildEnhancedInfo(),
              ),
            
            // Lane guidance
            if (_hasLaneGuidance())
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: LaneGuidanceWidget(
                  lanes: step.intersections.first.lanes,
                ),
              ),

            // Next-next instruction preview (Waze-style)
            if (nextStep != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _buildNextStepPreview(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildManeuverIcon(MapboxManeuver maneuver) {
    final iconText = MapboxNavigationUtils.getManeuverIcon(maneuver.type, maneuver.modifier);
    
    // Handle roundabout with exit numbers
    if (maneuver.type == 'roundabout' && maneuver.exit != null) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Text(iconText, style: const TextStyle(fontSize: 32, color: Colors.black)),
          Positioned(
            bottom: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${maneuver.exit}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      );
    }
    
    return Text(iconText, style: const TextStyle(fontSize: 32, color: Colors.black));
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

  bool _hasLaneGuidance() {
    return step.intersections.isNotEmpty && step.intersections.first.lanes.isNotEmpty;
  }

  Widget _buildNextStepPreview() {
    if (nextStep == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          // "Then" label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'THEN',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Next maneuver icon (smaller)
          Text(
            MapboxNavigationUtils.getManeuverIcon(
              nextStep!.maneuver.type,
              nextStep!.maneuver.modifier,
            ),
            style: const TextStyle(fontSize: 20, color: Colors.black),
          ),
          const SizedBox(width: 8),

          // Next instruction text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nextStep!.maneuver.instruction,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (nextStep!.name.isNotEmpty)
                  Text(
                    nextStep!.name,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // Distance to next step
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              MapboxNavigationUtils.formatDistance(
                step.distance, // Distance of current step
              ),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
