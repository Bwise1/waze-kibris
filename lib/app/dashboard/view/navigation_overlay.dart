// Updated navigation_overlay.dart - Using Mapbox Navigation
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:waze_kibris/app/dashboard/bloc/navigation_bloc.dart';
import 'package:waze_kibris/app/dashboard/view/mapbox_navigation_utils.dart';
import 'package:waze_kibris/core/models/directions/mapbox_directions_response.dart';

class NavigationOverlay extends StatefulWidget {
  final NavigationInProgress navigationState;
  final VoidCallback onEndNavigation;
  final VoidCallback onToggleOverview;

  const NavigationOverlay({
    Key? key,
    required this.navigationState,
    required this.onEndNavigation,
    required this.onToggleOverview,
  }) : super(key: key);

  @override
  State<NavigationOverlay> createState() => _NavigationOverlayState();
}

class _NavigationOverlayState extends State<NavigationOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  bool _isMuted = false;
  final Set<String> _announcedSteps = <String>{};
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 500), // Standard transition duration
      vsync: this,
    )..repeat();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300), // Standard transition duration
      vsync: this,
    );

    // Start timer for real-time updates every 3 seconds for stability
    _updateTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          // Force rebuild to update distance display - reduced frequency
        });
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(NavigationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Animate when step advances
    if (oldWidget.navigationState.currentStepIndex !=
        widget.navigationState.currentStepIndex) {
      _slideController.forward().then((_) {
        _slideController.reverse();
      });

      // Check if we should announce the new step
      _checkVoiceAnnouncement();
    }

    // Force rebuild when distance to next maneuver changes
    if (oldWidget.navigationState.distanceToNextManeuver !=
        widget.navigationState.distanceToNextManeuver) {
      setState(() {
        // Update banner with new distance
      });
    }
  }

  void _checkVoiceAnnouncement() {
    if (_isMuted) return;

    final step = widget.navigationState.currentStep;
    final stepId = '${widget.navigationState.currentStepIndex}';
    final distance = widget.navigationState.distanceToNextManeuver;

    if (_shouldAnnounceManeuver(distance, stepId)) {
      final voiceText = _generateVoiceInstruction(step, distance);
      _announcedSteps.add('${stepId}_${distance.round()}');
      // Here you would integrate with your TTS system
      debugPrint('Voice: $voiceText');
    }
  }

  bool _shouldAnnounceManeuver(double distance, String stepId) {
    final announceKey = '${stepId}_${distance.round()}';
    if (_announcedSteps.contains(announceKey)) return false;
    
    // Announce at specific distances (similar to professional nav apps)
    return distance <= 500 && distance > 50; // 500m to 50m range
  }

  String _generateVoiceInstruction(MapboxStep step, double distance) {
    final instruction = step.maneuver.instruction;
    final formattedDistance = MapboxNavigationUtils.formatDistance(distance);
    
    if (distance > 200) {
      return 'In $formattedDistance, $instruction';
    } else {
      return instruction; // Just the instruction for close distances
    }
  }

  Color _getManeuverColor(String maneuverType) {
    switch (maneuverType.toLowerCase()) {
      case 'turn':
        return Colors.blue;
      case 'depart':
        return Colors.green;
      case 'arrive':
        return Colors.red;
      case 'merge':
        return Colors.orange;
      case 'on ramp':
      case 'off ramp':
        return Colors.purple;
      case 'fork':
        return Colors.amber;
      case 'roundabout':
        return Colors.indigo;
      case 'continue':
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.navigationState.currentStep;
    final navigationState = widget.navigationState;

    return Column(
      children: [
        // Top maneuver instruction panel
        AnimatedBuilder(
          animation: _slideController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, -50 * _slideController.value),
              child: AnimatedOpacity(
                opacity: 1 - _slideController.value,
                duration: const Duration(milliseconds: 100),
                child: Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top - 50,
                    left: 16,
                    right: 16,
                  ),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Animated maneuver icon using NavigationUtils
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 1.0 + (_pulseController.value * 0.1),
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: _getManeuverColor(step.maneuver.type),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                MapboxNavigationUtils.getManeuverIcon(
                                    step.maneuver.type, step.maneuver.modifier),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Distance to next maneuver using MapboxNavigationUtils formatting
                            Text(
                              navigationState.distanceToNextManeuver > 0
                                  ? MapboxNavigationUtils.formatDistance(
                                      navigationState.distanceToNextManeuver)
                                  : MapboxNavigationUtils.formatDistance(
                                      step.distance),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Maneuver instruction using MapboxNavigationUtils
                            Text(
                              MapboxNavigationUtils.cleanInstruction(step.maneuver.instruction),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            // Road name using MapboxNavigationUtils
                            if (MapboxNavigationUtils.extractRoadName(step.name) != null)
                              Text(
                                MapboxNavigationUtils.extractRoadName(step.name)!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Voice guidance button
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _isMuted = !_isMuted;
                          });
                        },
                        icon: Icon(
                          _isMuted ? Icons.volume_off : Icons.volume_up,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        const Spacer(),

        // Bottom navigation controls
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Progress indicator
              if (!navigationState.isOverviewVisible) ...[
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value:
                            (navigationState.route.distance -
                                    navigationState.remainingDistance) /
                                navigationState.route.distance,
                        backgroundColor: Colors.grey[200],
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.red),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // ETA and distance info using NavigationUtils formatting
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        MapboxNavigationUtils.formatDuration(
                            navigationState.remainingDuration),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        'ETA ${MapboxNavigationUtils.formatETA(navigationState.remainingDuration)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey[300],
                  ),
                  Column(
                    children: [
                      Text(
                        MapboxNavigationUtils.formatDistance(
                            navigationState.remainingDistance),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        'Distance',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Control buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlButton(
                    icon: navigationState.isOverviewVisible
                        ? Icons.navigation
                        : Icons.map_outlined,
                    label: navigationState.isOverviewVisible
                        ? 'Navigate'
                        : 'Overview',
                    onPressed: widget.onToggleOverview,
                  ),
                  _buildControlButton(
                    icon: _isMuted ? Icons.volume_off : Icons.volume_up,
                    label: _isMuted ? 'Unmute' : 'Mute',
                    onPressed: () {
                      setState(() {
                        _isMuted = !_isMuted;
                      });
                    },
                  ),
                  _buildControlButton(
                    icon: Icons.close,
                    label: 'End',
                    onPressed: () {
                      _showEndNavigationDialog(context);
                    },
                    isDestructive: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isDestructive = false,
  }) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isDestructive ? Colors.red[50] : Colors.grey[100],
            borderRadius: BorderRadius.circular(25),
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(
              icon,
              color: isDestructive ? Colors.red : Colors.grey[700],
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDestructive ? Colors.red : Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showEndNavigationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('End Navigation'),
          content: const Text('Are you sure you want to end navigation?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onEndNavigation();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('End Navigation'),
            ),
          ],
        );
      },
    );
  }
}
