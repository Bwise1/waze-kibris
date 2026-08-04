import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:waze_kibris/app/dashboard/view/mapbox_navigation_utils.dart';
import 'package:waze_kibris/core/constants/navigation_camera_constants.dart';
import 'package:waze_kibris/core/controllers/camera_controller.dart';
import 'package:waze_kibris/core/controllers/navigation_controller.dart'
    as nav_controller;
import 'package:waze_kibris/core/models/directions/mapbox_directions_response.dart';
import 'package:waze_kibris/core/models/navigation/travel_mode.dart';
import 'package:waze_kibris/core/models/navigation/waypoint.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:waze_kibris/app/dashboard/services/voice_instruction_service.dart';
import 'package:waze_kibris/app/dashboard/view/places_service.dart';
import 'package:waze_kibris/di.dart';

part 'navigation_event.dart';
part 'navigation_state.dart';

class NavigationBloc extends Bloc<NavigationEvent, NavigationState> {
  final CameraController? _cameraController;
  final nav_controller.NavigationController? _navigationController;
  final VoiceInstructionService _voiceService = VoiceInstructionService();

  // Circuit breaker fields for preventing infinite reroute loops
  int _consecutiveReroutes = 0;
  DateTime? _lastRerouteTime;
  static const int _maxConsecutiveReroutes = 5;
  static const Duration _rerouteCooldownPeriod = Duration(seconds: 60);

  NavigationBloc({
    CameraController? cameraController,
    nav_controller.NavigationController? navigationController,
  })  : _cameraController = cameraController,
        _navigationController = navigationController,
        super(NavigationInitial()) {
    on<NavigationStarted>(_onNavigationStarted);
    on<NavigationStopped>(_onNavigationStopped);
    on<NavigationPositionUpdated>(_onPositionUpdated);
    on<NavigationOverviewToggled>(_onOverviewToggled);
    on<NavigationStepCompleted>(_onStepCompleted);
    on<NavigationRerouteRequested>(_onRerouteRequested);
    on<ClearRerouteError>(_onClearRerouteError);

    // Initialize voice service
    _voiceService.initialize();
  }

  // Voice service getters for UI access
  bool get isVoiceEnabled => _voiceService.isEnabled;

  void toggleVoice() {
    _voiceService.isEnabled = !_voiceService.isEnabled;
  }

  Future<void> speakCurrentInstruction() async {
    final currentState = state;
    if (currentState is NavigationInProgress) {
      await _voiceService.speakCurrentInstruction(currentState.currentStep);
    }
  }

  void _onNavigationStarted(
      NavigationStarted event, Emitter<NavigationState> emit) {
    final firstStep = event.route.legs.first.steps.first;
    // Determine next step if available
    final nextStep = event.route.legs.first.steps.length > 1
        ? event.route.legs.first.steps[1]
        : null;

    // Speed limit + congestion are only meaningful for vehicle modes. Walking
    // in a pedestrian zone shouldn't show a "50 km/h" sign.
    double? speedLimit;
    double? expectedAverageSpeed;
    List<double>? congestionNumericData;
    if (event.mode.isVehicle && event.route.legs.isNotEmpty) {
      final firstLeg = event.route.legs.first;
      // Look up the posted speed limit at the route origin so the sign is
      // correct before the first GPS fix arrives.
      final firstCoord = firstStep.geometry.coordinates.isNotEmpty
          ? firstStep.geometry.coordinates.first
          : null;
      if (firstCoord != null) {
        speedLimit = firstLeg.speedLimitKmhAt(
          LatLng(firstCoord[1], firstCoord[0]),
        );
      }
      expectedAverageSpeed = firstLeg.expectedAverageSpeed;
      congestionNumericData = firstLeg.annotations?.congestionNumeric;
    }

    // Enable navigation mode on camera controller with the selected travel
    // mode so zoom/pitch are tuned for walking vs driving from frame 1.
    _cameraController?.setTravelMode(event.mode);
    _cameraController?.enableNavigationMode();

    // Reset voice service for new navigation session and tune cadence per mode.
    _voiceService.reset();
    _voiceService.setSpeechRate(event.mode.voiceSpeechRate);

    emit(NavigationInProgress(
      route: event.route,
      mode: event.mode,
      currentStep: firstStep,
      nextStep: nextStep,
      currentStepIndex: 0,
      currentLegIndex: 0,
      remainingDistance: event.route.distance, // Mapbox uses double directly
      remainingDuration: event.route.duration, // Mapbox uses double directly
      isOverviewVisible: false,
      speedLimit: speedLimit,
      routeStartTime: DateTime.now(),
      expectedAverageSpeed: expectedAverageSpeed,
      congestionNumericData: congestionNumericData,
    ));

    WakelockPlus.enable();

    // Prepare audio session and speak first instruction so user hears voice immediately
    _voiceService.prepareForNavigation();
    _voiceService.speakCurrentInstruction(firstStep);
  }

  void _onNavigationStopped(
      NavigationStopped event, Emitter<NavigationState> emit) {
    WakelockPlus.disable();

    // Disable navigation mode on camera controller
    _cameraController?.disableNavigationMode();

    // Stop voice instructions
    _voiceService.stop();

    emit(NavigationInitial());
  }

  void _onPositionUpdated(
      NavigationPositionUpdated event, Emitter<NavigationState> emit) async {
    final currentState = state;
    if (currentState is NavigationInProgress) {
      // Update camera position using camera controller
      _cameraController?.updateCamera(
        userPosition: event.position,
        userBearing:
            event.position.heading >= 0 ? event.position.heading : null,
      );

      final updatedState = _updateNavigationProgress(currentState, event);

      // Trigger reroute when snap service reported needsReroute (single source of truth)
      if (updatedState.isRerouting && !currentState.isRerouting) {
        add(NavigationRerouteRequested());
      }

      // Process voice instructions for current step (uses along-route distance when available)
      await _voiceService.processVoiceInstructions(
        updatedState.currentStep,
        updatedState.distanceToNextManeuver,
      );

      emit(updatedState);
    }
  }

  void _onOverviewToggled(
      NavigationOverviewToggled event, Emitter<NavigationState> emit) {
    final currentState = state;
    if (currentState is NavigationInProgress) {
      final newOverviewState = !currentState.isOverviewVisible;

      // Update camera mode based on overview state
      if (currentState.userPosition != null) {
        _cameraController?.updateCamera(
          userPosition: currentState.userPosition!,
          userBearing: currentState.userPosition!.heading >= 0
              ? currentState.userPosition!.heading
              : null,
          isOverviewMode: newOverviewState,
        );
      }

      emit(currentState.copyWith(
        isOverviewVisible: newOverviewState,
      ));
    }
  }

  void _onStepCompleted(
      NavigationStepCompleted event, Emitter<NavigationState> emit) {
    final currentState = state;
    if (currentState is NavigationInProgress) {
      _advanceToNextStep(currentState, emit);
    }
  }

  void _onClearRerouteError(
      ClearRerouteError event, Emitter<NavigationState> emit) {
    if (state is NavigationInProgress) {
      emit((state as NavigationInProgress).copyWith(rerouteError: ''));
    }
  }

  /// Helper method to fetch route with exponential backoff retry
  Future<MapboxDirectionsResponse?> _fetchRouteWithRetry({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required String profile,
    int maxRetries = 2,
  }) async {
    final placesService = getIt<PlacesService>();
    int attempt = 0;

    while (attempt <= maxRetries) {
      try {
        final response = await placesService
            .fetchMapboxDirections(
              originLat: originLat,
              originLng: originLng,
              destinationLat: destLat,
              destinationLng: destLng,
              profile: profile,
              alternatives: false,
            )
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () =>
                  throw TimeoutException('Reroute request timed out'),
            );

        // Success - return immediately
        return response;
      } catch (e) {
        attempt++;

        if (attempt > maxRetries) {
          // All retries exhausted
          rethrow;
        }

        // Exponential backoff: 1s, 2s, 4s
        final delaySeconds = 1 << (attempt - 1);
        print(
            '⚠️ Reroute attempt $attempt failed: $e. Retrying in ${delaySeconds}s...');
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }

    return null; // Should never reach here
  }

  void _onRerouteRequested(
      NavigationRerouteRequested event, Emitter<NavigationState> emit) async {
    final currentState = state;
    if (currentState is NavigationInProgress) {
      // Circuit breaker check
      final now = DateTime.now();
      if (_lastRerouteTime != null) {
        final timeSinceLastReroute = now.difference(_lastRerouteTime!);

        if (timeSinceLastReroute < _rerouteCooldownPeriod) {
          _consecutiveReroutes++;

          if (_consecutiveReroutes >= _maxConsecutiveReroutes) {
            print(
                '🚨 Circuit breaker: Too many reroutes ($_consecutiveReroutes) in ${timeSinceLastReroute.inSeconds}s');
            if (!isClosed) {
              emit(currentState.copyWith(
                isRerouting: false,
                rerouteError:
                    'Too many reroute attempts. Navigation paused for 1 minute.',
              ));
            }

            // Reset after cooldown
            Future.delayed(_rerouteCooldownPeriod, () {
              _consecutiveReroutes = 0;
              _lastRerouteTime = null;
            });
            return;
          }
        } else {
          // Cooldown period passed, reset counter
          _consecutiveReroutes = 0;
        }
      }

      _lastRerouteTime = now;

      // 1. Set rerouting flag
      emit(currentState.copyWith(isRerouting: true));

      try {
        final currentPos = currentState.userPosition;

        if (currentPos == null) {
          print('❌ Cannot reroute: Unknown user position');
          if (!isClosed) {
            emit(currentState.copyWith(isRerouting: false));
          }
          return;
        }

        // Validate route structure before extracting destination
        if (currentState.route.legs.isEmpty) {
          print('❌ Cannot reroute: Route has no legs');
          if (!isClosed) {
            emit(currentState.copyWith(
              isRerouting: false,
              rerouteError: 'Cannot reroute: Invalid route data',
            ));
          }
          return;
        }

        final lastLeg = currentState.route.legs.last;
        if (lastLeg.steps.isEmpty) {
          print('❌ Cannot reroute: Route has no steps');
          if (!isClosed) {
            emit(currentState.copyWith(
              isRerouting: false,
              rerouteError: 'Cannot reroute: Invalid route data',
            ));
          }
          return;
        }

        final lastStep = lastLeg.steps.last;
        if (lastStep.maneuver.location.length < 2) {
          print('❌ Cannot reroute: Invalid destination location format');
          if (!isClosed) {
            emit(currentState.copyWith(
              isRerouting: false,
              rerouteError: 'Cannot reroute: Invalid destination location',
            ));
          }
          return;
        }

        final destLat = lastStep.maneuver.location[1];
        final destLng = lastStep.maneuver.location[0];

        print(
            '🔄 Rerouting from (${currentPos.latitude}, ${currentPos.longitude}) to ($destLat, $destLng)...');

        // 2. Fetch new route with retry and timeout, using the mode the user
        // originally started navigation in.
        final response = await _fetchRouteWithRetry(
          originLat: currentPos.latitude,
          originLng: currentPos.longitude,
          destLat: destLat,
          destLng: destLng,
          profile: currentState.mode.mapboxProfile,
          maxRetries: 2,
        );

        if (response == null) {
          throw Exception('Failed to fetch route after retries');
        }

        // Check if bloc is still open before emitting
        if (isClosed) {
          print('⚠️ Bloc closed during reroute, skipping state emission');
          return;
        }

        if (response.routes.isNotEmpty) {
          final newRoute = response.routes.first;
          print('✅ Reroute successful! New distance: ${newRoute.distance}m');

          // 3. Update state with new route
          // We treat this as starting a new navigation segment from current location
          final firstStep = newRoute.legs.first.steps.first;
          final nextStep = newRoute.legs.first.steps.length > 1
              ? newRoute.legs.first.steps[1]
              : null;

          // Get congestion data and expected speed from new route
          final newLeg = newRoute.legs.first;
          final newCongestionData = newLeg.annotations?.congestionNumeric;
          final newExpectedSpeed = newLeg.expectedAverageSpeed;

          emit(NavigationInProgress(
            route: newRoute,
            mode: currentState.mode,
            currentStep: firstStep,
            nextStep: nextStep,
            currentStepIndex: 0,
            currentLegIndex: 0,
            remainingDistance: newRoute.distance,
            remainingDuration: newRoute.duration,
            isOverviewVisible: currentState.isOverviewVisible,
            userPosition: currentPos,
            currentBearing: currentState.currentBearing,
            currentSpeed: currentState.currentSpeed,
            isRerouting: false, // Reset flag
            // Preserve progress tracking (keep start time and actual speed)
            routeStartTime: currentState.routeStartTime,
            actualAverageSpeed: currentState.actualAverageSpeed,
            expectedAverageSpeed: currentState.mode.isVehicle
                ? (newExpectedSpeed ?? currentState.expectedAverageSpeed)
                : null,
            congestionNumericData:
                currentState.mode.isVehicle ? newCongestionData : null,
          ));

          // Reset circuit breaker on success
          _consecutiveReroutes = 0;

          _voiceService.speak('Rerouting');
        } else {
          print('⚠️ Reroute failed: No routes found');
          if (!isClosed) {
            emit(currentState.copyWith(
              isRerouting: false,
              rerouteError: 'No alternative route found',
            ));
          }
        }
      } catch (e) {
        print('❌ Reroute error: $e');
        final errorMessage = e is TimeoutException
            ? 'Reroute timed out. Please try again.'
            : 'Could not calculate new route';

        if (!isClosed) {
          emit(currentState.copyWith(
            isRerouting: false,
            rerouteError: errorMessage,
          ));
        }
      }
    }
  }

  /// Step advance threshold when using along-route distance (native parity: advance when passed maneuver)
  static const double _passedManeuverThresholdMeters = 10.0;

  NavigationInProgress _updateNavigationProgress(
      NavigationInProgress state, NavigationPositionUpdated event) {
    final position = event.position;
    final currentStep = state.currentStep;
    final allSteps = state.route.legs[state.currentLegIndex].steps;

    // Prefer along-route distance from snap (native SDK parity); fallback to straight-line
    double distanceToNextManeuver;
    if (event.distanceToManeuverAlongRouteMeters != null) {
      final d = event.distanceToManeuverAlongRouteMeters!;
      distanceToNextManeuver = d < 0 ? 0.0 : d; // treat "passed" as 0 for display
    } else {
      distanceToNextManeuver = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        currentStep.maneuver.location[1],
        currentStep.maneuver.location[0],
      );
      if (state.currentStepIndex < allSteps.length - 1) {
        final nextStep = allSteps[state.currentStepIndex + 1];
        distanceToNextManeuver = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          nextStep.maneuver.location[1],
          nextStep.maneuver.location[0],
        );
      }
    }

    // Step advancement: when along-route available, advance when passed maneuver (<= threshold past)
    bool shouldAdvanceStep;
    if (event.distanceToManeuverAlongRouteMeters != null) {
      final d = event.distanceToManeuverAlongRouteMeters!;
      shouldAdvanceStep = d <= _passedManeuverThresholdMeters &&
          state.currentStepIndex < allSteps.length - 1;
    } else {
      shouldAdvanceStep = _shouldAdvanceToNextStep(
        position,
        currentStep,
        distanceToNextManeuver,
        state.currentStepIndex,
        allSteps,
      );
    }

    // Remaining distance: prefer along-route from snap; fallback to util
    final remainingDistance =
        event.remainingDistanceAlongRouteMeters ??
        MapboxNavigationUtils.calculateRemainingDistance(
          position,
          currentStep,
          allSteps,
          state.currentStepIndex,
        );

    // Get congestion data from route annotations if available
    final currentLeg = state.route.legs[state.currentLegIndex];
    final congestionData = currentLeg.annotations?.congestionNumeric;

    // Look up the posted speed limit for the segment nearest the user. Keep
    // the previous value when Mapbox has no data for this stretch so the sign
    // doesn't flicker on/off between unmapped segments. Skipped entirely for
    // walking/cycling — a "50 km/h" sign on foot is nonsense.
    final speedLimit = state.mode.isVehicle
        ? (currentLeg.speedLimitKmhAt(
              LatLng(position.latitude, position.longitude),
            ) ??
            state.speedLimit)
        : null;

    // Calculate expected average speed from route
    final expectedAverageSpeed =
        currentLeg.expectedAverageSpeed ?? state.expectedAverageSpeed;

    // Calculate actual average speed based on progress
    double? actualAverageSpeed = state.actualAverageSpeed;
    final routeStartTime = state.routeStartTime;
    if (routeStartTime != null && position.speed > 0) {
      final elapsedTime = DateTime.now().difference(routeStartTime).inSeconds;
      if (elapsedTime > 0) {
        // Calculate distance traveled so far
        final totalDistance = state.route.distance;
        final distanceTraveled = totalDistance - remainingDistance;

        if (distanceTraveled > 0) {
          // Actual average speed = distance traveled / time elapsed
          actualAverageSpeed = distanceTraveled / elapsedTime;
        }
      }
    }

    final remainingDuration = MapboxNavigationUtils.calculateRemainingTime(
      remainingDistance,
      position.speed, // Current speed in m/s
      allSteps.sublist(state.currentStepIndex + 1),
      congestionNumericData: congestionData,
      actualAverageSpeed: actualAverageSpeed,
      expectedAverageSpeed: expectedAverageSpeed,
    );

    // Off-route/reroute: single source of truth from snap result (native SDK parity)
    final isRerouting = event.needsRerouteFromSnap == true;
    if (isRerouting) {
      print('⚠️ User off-route (snap): triggering reroute...');
    }

    // Enhanced destination reached detection (native parity: along-route when available, straight-line fallback; straight-line always allows arrival e.g. when user took another route)
    final isDestinationReached = _isDestinationReached(
      position,
      currentStep,
      state.currentStepIndex,
      allSteps,
      distanceToNextManeuver,
      remainingDistanceAlongRouteMeters: event.remainingDistanceAlongRouteMeters,
      isRerouting: isRerouting,
    );

    // Create updated state
    NavigationInProgress updatedState = state.copyWith(
      userPosition: position,
      distanceToNextManeuver: distanceToNextManeuver,
      remainingDistance: remainingDistance,
      remainingDuration: remainingDuration,
      isNavigationComplete: isDestinationReached,
      isRerouting: isRerouting,
      // Add bearing for camera tracking
      currentBearing: position.heading >= 0 ? position.heading : null,
      // Update current speed
      currentSpeed: position.speed,
      // Refresh posted speed limit for the current segment
      speedLimit: speedLimit,
      // Update progress tracking
      actualAverageSpeed: actualAverageSpeed,
      expectedAverageSpeed: expectedAverageSpeed,
      congestionNumericData: congestionData,
    );

    // Advance step if needed (native parity: clear voice state for new step)
    if (shouldAdvanceStep && state.currentStepIndex < allSteps.length - 1) {
      _voiceService.clearAnnouncedInstructionsForNewStep();
      updatedState = _advanceStep(updatedState);
    }

    return updatedState;
  }

  bool _shouldAdvanceToNextStep(
    Position position,
    MapboxStep currentStep,
    double distanceToNextManeuver,
    int currentStepIndex,
    List<MapboxStep> allSteps,
  ) {
    // Primary condition: within threshold distance
    if (distanceToNextManeuver > MapboxNavigationUtils.stepAdvanceThreshold) {
      return false;
    }

    // Secondary condition: check if we're actually progressing toward the next step
    if (currentStepIndex < allSteps.length - 1) {
      final nextStep = allSteps[currentStepIndex + 1];
      final distanceToNextStepEnd = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        nextStep.maneuver.location[1], // lat
        nextStep.maneuver.location[0], // lng
      );

      // Only advance if we're closer to the next step's end than to current step's end
      final distanceToCurrentStepEnd = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        currentStep.maneuver.location[1], // lat
        currentStep.maneuver.location[0], // lng
      );

      return distanceToNextStepEnd < distanceToCurrentStepEnd;
    }

    return true; // Last step, use simple threshold
  }

  bool _isDestinationReached(
    Position position,
    MapboxStep currentStep,
    int currentStepIndex,
    List<MapboxStep> allSteps,
    double distanceToNextManeuver, {
    double? remainingDistanceAlongRouteMeters,
    bool isRerouting = false,
  }) {
    // Only check for destination if we're on the last step
    if (currentStepIndex != allSteps.length - 1) {
      return false;
    }

    final finalStep = allSteps.last;
    final straightLineToDestination = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      finalStep.maneuver.location[1], // lat
      finalStep.maneuver.location[0], // lng
    );

    // Straight-line fallback: always allow arrival when physically at destination (e.g. user took another route but reached it)
    if (straightLineToDestination < kDestinationReachedThresholdMeters) {
      return true;
    }

    // Along-route (native-style): use remaining distance from snap when available; guard against arrival during reroute
    if (remainingDistanceAlongRouteMeters != null &&
        !isRerouting &&
        remainingDistanceAlongRouteMeters <= kDestinationReachedThresholdMeters) {
      return true;
    }

    return false;
  }

  NavigationInProgress _advanceStep(NavigationInProgress state) {
    final allSteps = state.route.legs[state.currentLegIndex].steps;
    final nextStepIndex = state.currentStepIndex + 1;

    if (nextStepIndex < allSteps.length) {
      // Determine the step after the next one (for preview)
      final nextNextStep = nextStepIndex + 1 < allSteps.length
          ? allSteps[nextStepIndex + 1]
          : null;

      return state.copyWith(
        currentStep: allSteps[nextStepIndex],
        nextStep: nextNextStep,
        currentStepIndex: nextStepIndex,
        hasAdvancedStep: true,
        // Reset any transient flags
        isRerouting: false,
      );
    }

    // Check if we need to move to next leg
    if (state.currentLegIndex < state.route.legs.length - 1) {
      final nextLeg = state.route.legs[state.currentLegIndex + 1];
      final nextStep = nextLeg.steps.length > 1 ? nextLeg.steps[1] : null;

      return state.copyWith(
        currentStep: nextLeg.steps.first,
        nextStep: nextStep,
        currentStepIndex: 0,
        currentLegIndex: state.currentLegIndex + 1,
        hasAdvancedStep: true,
        isRerouting: false,
      );
    }

    // Navigation completed
    return state.copyWith(
      isNavigationComplete: true,
      hasAdvancedStep: false,
    );
  }

  void _advanceToNextStep(
      NavigationInProgress state, Emitter<NavigationState> emit) {
    final updatedState = _advanceStep(state);
    emit(updatedState);
  }
}
