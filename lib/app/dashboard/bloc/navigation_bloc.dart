import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';
import 'package:waze_kibris/app/dashboard/view/navigation_utils.dart';
import 'package:waze_kibris/core/models/directions/google_directions_response.dart';

part 'navigation_event.dart';
part 'navigation_state.dart';

class NavigationBloc extends Bloc<NavigationEvent, NavigationState> {
  NavigationBloc() : super(NavigationInitial()) {
    on<NavigationStarted>(_onNavigationStarted);
    on<NavigationStopped>(_onNavigationStopped);
    on<NavigationPositionUpdated>(_onPositionUpdated);
    on<NavigationOverviewToggled>(_onOverviewToggled);
    on<NavigationStepCompleted>(_onStepCompleted);
    on<NavigationRerouteRequested>(_onRerouteRequested);
  }

  void _onNavigationStarted(
      NavigationStarted event, Emitter<NavigationState> emit) {
    final firstStep = event.route.legs.first.steps.first;
    emit(NavigationInProgress(
      route: event.route,
      currentStep: firstStep,
      currentStepIndex: 0,
      currentLegIndex: 0,
      remainingDistance: event.route.legs.first.distance.value,
      remainingDuration: event.route.legs.first.duration.value,
      isOverviewVisible: false,
    ));
  }

  void _onNavigationStopped(
      NavigationStopped event, Emitter<NavigationState> emit) {
    emit(NavigationInitial());
  }

  void _onPositionUpdated(
      NavigationPositionUpdated event, Emitter<NavigationState> emit) {
    final currentState = state;
    if (currentState is NavigationInProgress) {
      final updatedState =
          _updateNavigationProgress(currentState, event.position);
      emit(updatedState);
    }
  }

  void _onOverviewToggled(
      NavigationOverviewToggled event, Emitter<NavigationState> emit) {
    final currentState = state;
    if (currentState is NavigationInProgress) {
      emit(currentState.copyWith(
        isOverviewVisible: !currentState.isOverviewVisible,
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

  void _onRerouteRequested(
      NavigationRerouteRequested event, Emitter<NavigationState> emit) {
    final currentState = state;
    if (currentState is NavigationInProgress) {
      emit(currentState.copyWith(isRerouting: true));
      // Implement rerouting logic here
    }
  }

  NavigationInProgress _updateNavigationProgress(
      NavigationInProgress state, Position position) {
    final currentStep = state.currentStep;
    final allSteps = state.route.legs[state.currentLegIndex].steps;

    // Calculate distance to next maneuver using NavigationUtils
    double distanceToNextManeuver = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      currentStep.endLoc.lat,
      currentStep.endLoc.lng,
    );

    // For better accuracy, calculate distance to the actual next maneuver point
    if (state.currentStepIndex < allSteps.length - 1) {
      final nextStep = allSteps[state.currentStepIndex + 1];
      distanceToNextManeuver = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        nextStep.startLoc.lat,
        nextStep.startLoc.lng,
      );
    }

    // Enhanced step advancement logic - more precise
    bool shouldAdvanceStep = _shouldAdvanceToNextStep(
      position,
      currentStep,
      distanceToNextManeuver,
      state.currentStepIndex,
      allSteps,
    );

    // Calculate remaining route distance and time using NavigationUtils
    final remainingDistance = NavigationUtils.calculateRemainingDistance(
      position,
      currentStep,
      allSteps,
      state.currentStepIndex,
    ).round();

    final remainingDuration = NavigationUtils.calculateRemainingTime(
      remainingDistance.toDouble(),
      position.speed, // Current speed in m/s
      allSteps.sublist(state.currentStepIndex + 1),
    );

    // Enhanced off-route detection
    final isOffRoute = NavigationUtils.isOffRoute(position, currentStep) &&
        !state.isRerouting; // Don't trigger if already rerouting

    // Enhanced destination reached detection
    final isDestinationReached = _isDestinationReached(
      position,
      currentStep,
      state.currentStepIndex,
      allSteps,
      distanceToNextManeuver,
    );

    // Create updated state
    NavigationInProgress updatedState = state.copyWith(
      userPosition: position,
      distanceToNextManeuver: distanceToNextManeuver.round(),
      remainingDistance: remainingDistance,
      remainingDuration: remainingDuration,
      isNavigationComplete: isDestinationReached,
      isRerouting: isOffRoute,
      // Add bearing for camera tracking
      currentBearing: position.heading >= 0 ? position.heading : null,
    );

    // Advance step if needed
    if (shouldAdvanceStep && state.currentStepIndex < allSteps.length - 1) {
      updatedState = _advanceStep(updatedState);
    }

    return updatedState;
  }

  bool _shouldAdvanceToNextStep(
    Position position,
    DirectionsStep currentStep,
    double distanceToNextManeuver,
    int currentStepIndex,
    List<DirectionsStep> allSteps,
  ) {
    // Primary condition: within threshold distance
    if (distanceToNextManeuver > NavigationUtils.stepAdvanceThreshold) {
      return false;
    }

    // Secondary condition: check if we're actually progressing toward the next step
    if (currentStepIndex < allSteps.length - 1) {
      final nextStep = allSteps[currentStepIndex + 1];
      final distanceToNextStepEnd = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        nextStep.endLoc.lat,
        nextStep.endLoc.lng,
      );

      // Only advance if we're closer to the next step's end than to current step's end
      final distanceToCurrentStepEnd = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        currentStep.endLoc.lat,
        currentStep.endLoc.lng,
      );

      return distanceToNextStepEnd < distanceToCurrentStepEnd;
    }

    return true; // Last step, use simple threshold
  }

  bool _isDestinationReached(
    Position position,
    DirectionsStep currentStep,
    int currentStepIndex,
    List<DirectionsStep> allSteps,
    double distanceToNextManeuver,
  ) {
    // Only check for destination if we're on the last step
    if (currentStepIndex != allSteps.length - 1) {
      return false;
    }

    // Calculate distance to final destination
    final finalStep = allSteps.last;
    final distanceToDestination = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      finalStep.endLoc.lat,
      finalStep.endLoc.lng,
    );

    return distanceToDestination < NavigationUtils.destinationReachedThreshold;
  }

  NavigationInProgress _advanceStep(NavigationInProgress state) {
    final allSteps = state.route.legs[state.currentLegIndex].steps;
    final nextStepIndex = state.currentStepIndex + 1;

    if (nextStepIndex < allSteps.length) {
      return state.copyWith(
        currentStep: allSteps[nextStepIndex],
        currentStepIndex: nextStepIndex,
        hasAdvancedStep: true,
        // Reset any transient flags
        isRerouting: false,
      );
    }

    // Check if we need to move to next leg
    if (state.currentLegIndex < state.route.legs.length - 1) {
      final nextLeg = state.route.legs[state.currentLegIndex + 1];
      return state.copyWith(
        currentStep: nextLeg.steps.first,
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
