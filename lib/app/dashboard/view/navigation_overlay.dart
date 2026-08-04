// Updated navigation_overlay.dart - Using Mapbox Navigation
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:waze_kibris/app/dashboard/bloc/navigation_bloc.dart';
import 'package:waze_kibris/app/dashboard/modals/report_modal.dart';
import 'package:waze_kibris/app/dashboard/view/mapbox_navigation_utils.dart';
import 'package:waze_kibris/app/dashboard/view/maneuver_banner.dart';
import 'package:waze_kibris/app/dashboard/view/speedometer_widget.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/bloc/auth/auth_bloc.dart';
import 'package:waze_kibris/core/bloc/auth/auth_event.dart';

class NavigationOverlay extends StatefulWidget {
  final NavigationInProgress navigationState;
  final VoidCallback onEndNavigation;
  final VoidCallback onToggleOverview;
  final VoidCallback onToggleCourseUp;
  final VoidCallback onRecenter;
  final bool isCourseUp;
  final bool isFollowingUser;

  const NavigationOverlay({
    Key? key,
    required this.navigationState,
    required this.onEndNavigation,
    required this.onToggleOverview,
    required this.onToggleCourseUp,
    required this.onRecenter,
    required this.isCourseUp,
    required this.isFollowingUser,
  }) : super(key: key);

  @override
  State<NavigationOverlay> createState() => _NavigationOverlayState();
}

class _NavigationOverlayState extends State<NavigationOverlay>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _panelSlideController;
  bool _isMuted = false;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _panelSlideController = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );
    _panelSlideController.forward();

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
    _slideController.dispose();
    _panelSlideController.dispose();
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
    }

    // Show snackbar when reroute error occurs
    if (widget.navigationState.rerouteError != null &&
        widget.navigationState.rerouteError!.isNotEmpty &&
        oldWidget.navigationState.rerouteError !=
            widget.navigationState.rerouteError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.navigationState.rerouteError!),
              backgroundColor: Colors.red.shade700,
              action: SnackBarAction(
                label: 'Dismiss',
                textColor: Colors.white,
                onPressed: () {
                  // Clear error
                  context.read<NavigationBloc>().add(ClearRerouteError());
                },
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final navigationState = widget.navigationState;

    return Stack(
      children: [
        // Top: Maneuver Banner
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ManeuverBanner(
            step: navigationState.currentStep,
            distanceRemaining: navigationState.distanceToNextManeuver > 0
                ? navigationState.distanceToNextManeuver
                : navigationState.currentStep.distance,
            navigationBloc: context.read<NavigationBloc>(),
            nextStep: navigationState.nextStep,
            mode: navigationState.mode,
          ),
        ),

        // Bottom Left: Speedometer — vehicle modes only. Walking with a
        // speed sign is nonsense and takes up real estate near the puck.
        if (navigationState.mode.isVehicle)
          Positioned(
            bottom: 192,
            left: 16,
            child: SpeedometerWidget(
              currentSpeed: navigationState.currentSpeed ?? 0,
              // Only enforce TTS / red border when Mapbox provides a limit
              speedLimit: navigationState.speedLimit,
            ),
          ),

        // Bottom Right: Compass Toggle Button — above the report button
        Positioned(
          bottom: 260,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'compass_fab_nav',
            onPressed: widget.onToggleCourseUp,
            backgroundColor: Colors.white,
            mini: true,
            child: Icon(
              widget.isCourseUp ? Icons.explore : Icons.explore_off,
              color: widget.isCourseUp ? Colors.blueAccent : Colors.grey,
            ),
          ),
        ),

        // Recenter FAB — only visible when the driver has panned away from
        // their current position. Tap to snap the camera back and resume
        // course-up follow. Placed just above the compass so both live in
        // the same right-edge column.
        if (!widget.isFollowingUser)
          Positioned(
            bottom: 310,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'recenter_fab_nav',
              onPressed: widget.onRecenter,
              backgroundColor: Colors.white,
              mini: true,
              child: const Icon(
                Icons.gps_fixed,
                color: Colors.blueAccent,
              ),
            ),
          ),

        // Bottom Right: Report Button — above bottom panel with clear gap
        Positioned(
          bottom: 192,
          right: 16,
          child: FloatingActionButton(
            onPressed: () => _showReportModal(context),
            backgroundColor: Colors.orange,
            child: const Icon(Icons.report_problem, color: Colors.white),
          ),
        ),

        // Bottom: Navigation Controls & Info — flush with screen bottom, slides up from beneath
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _panelSlideController,
              curve: Curves.easeOutCubic,
            )),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8, bottom: 0),
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: 8,
                bottom: 8 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress indicator
                  if (!navigationState.isOverviewVisible) ...[
                    Builder(builder: (context) {
                      // Calculate progress safely to avoid NaN/Infinity errors
                      double progress = 0.0;
                      if (navigationState.route.distance > 0) {
                        progress = (navigationState.route.distance -
                                navigationState.remainingDistance) /
                            navigationState.route.distance;
                        // Ensure valid range [0.0, 1.0]
                        progress = progress.clamp(0.0, 1.0);
                      }

                      return Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.grey[200],
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.blue),
                              minHeight: 4,
                            ),
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 10),
                  ],

                  // ETA and distance info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            MapboxNavigationUtils.formatDuration(
                                navigationState.remainingDuration),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'ETA ${MapboxNavigationUtils.formatETA(navigationState.remainingDuration)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              // Show indicator if congestion data is available (real-time traffic)
                              if (navigationState.congestionNumericData !=
                                      null &&
                                  navigationState
                                      .congestionNumericData!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Icon(
                                    Icons.traffic,
                                    size: 12,
                                    color: Colors.orange[700],
                                  ),
                                ),
                              // Show "Rerouting..." and spinner when route is being recalculated
                              if (navigationState.isRerouting)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.blue[700]!,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Rerouting...',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
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
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            'Distance',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Control buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildControlButton(
                        icon: navigationState.isOverviewVisible
                            ? Icons.navigation
                            : Icons.map_outlined,
                        label: navigationState.isOverviewVisible
                            ? 'Resume'
                            : 'Overview',
                        onPressed: widget.onToggleOverview,
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
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDestructive ? Colors.red[50] : Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isDestructive ? Colors.red : Colors.grey[700],
                size: 18,
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
        ),
      ),
    );
  }

  void _showEndNavigationDialog(BuildContext context) {
    showDialog<void>(
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

  void _showReportModal(BuildContext context) async {
    // Get current position from navigation state or fetch it
    Position? currentPosition = widget.navigationState.userPosition;

    // If position not available, fetch it
    if (currentPosition == null) {
      try {
        currentPosition = await Geolocator.getCurrentPosition();
      } catch (e) {
        debugPrint('Error getting position for report: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to get current location')),
        );
        return;
      }
    }

    // Set user coordinate in AuthBloc so ReportEventModal can use it
    if (context.mounted) {
      context.read<AuthBloc>().add(
            AuthEvent.getUserCoordinateRequested(
              context: context,
            ),
          );

      // Wait a moment for AuthBloc to update, then show modal
      await Future<void>.delayed(const Duration(milliseconds: 100));

      if (context.mounted) {
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const ReportEventModal(),
        );
      }
    }
  }
}
