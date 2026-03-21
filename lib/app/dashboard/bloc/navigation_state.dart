// Enhanced NavigationState with additional fields for better camera tracking
part of 'navigation_bloc.dart';

abstract class NavigationState extends Equatable {
  const NavigationState();

  @override
  List<Object?> get props => [];
}

class NavigationInitial extends NavigationState {}

class NavigationInProgress extends NavigationState {
  final MapboxRoute route;
  final MapboxStep currentStep;
  final MapboxStep? nextStep; // Added for "Then" preview
  final int currentStepIndex;
  final int currentLegIndex;
  final Position? userPosition;
  final bool isOverviewVisible;
  final double distanceToNextManeuver;
  final double remainingDistance;
  final double remainingDuration;
  final bool isRerouting;
  final bool hasAdvancedStep;
  final bool isNavigationComplete;
  final double? currentBearing; // Added for camera tracking
  final double? currentSpeed; // Added for speed tracking
  final double?
      speedLimit; // Estimated speed limit from route annotations (km/h)
  final DateTime? routeStartTime; // When navigation started
  final double? actualAverageSpeed; // Average speed so far (m/s)
  final double? expectedAverageSpeed; // Expected average from route (m/s)
  final List<double>?
      congestionNumericData; // congestion_numeric values (0-100) for remaining route segments
  final String? rerouteError; // Error message when reroute fails

  const NavigationInProgress({
    required this.route,
    required this.currentStep,
    this.nextStep,
    required this.currentStepIndex,
    required this.currentLegIndex,
    this.userPosition,
    this.isOverviewVisible = false,
    this.distanceToNextManeuver = 0.0,
    required this.remainingDistance,
    required this.remainingDuration,
    this.isRerouting = false,
    this.hasAdvancedStep = false,
    this.isNavigationComplete = false,
    this.currentBearing,
    this.currentSpeed,
    this.speedLimit,
    this.routeStartTime,
    this.actualAverageSpeed,
    this.expectedAverageSpeed,
    this.congestionNumericData,
    this.rerouteError,
  });

  @override
  List<Object?> get props => [
        route,
        currentStep,
        nextStep,
        currentStepIndex,
        currentLegIndex,
        userPosition,
        isOverviewVisible,
        distanceToNextManeuver,
        remainingDistance,
        remainingDuration,
        isRerouting,
        hasAdvancedStep,
        isNavigationComplete,
        currentBearing,
        currentSpeed,
        speedLimit,
        routeStartTime,
        actualAverageSpeed,
        expectedAverageSpeed,
        congestionNumericData,
        rerouteError,
      ];

  NavigationInProgress copyWith({
    MapboxRoute? route,
    MapboxStep? currentStep,
    MapboxStep? nextStep,
    int? currentStepIndex,
    int? currentLegIndex,
    Position? userPosition,
    bool? isOverviewVisible,
    double? distanceToNextManeuver,
    double? remainingDistance,
    double? remainingDuration,
    bool? isRerouting,
    bool? hasAdvancedStep,
    bool? isNavigationComplete,
    double? currentBearing,
    double? currentSpeed,
    double? speedLimit,
    DateTime? routeStartTime,
    double? actualAverageSpeed,
    double? expectedAverageSpeed,
    List<double>? congestionNumericData,
    String? rerouteError,
  }) {
    return NavigationInProgress(
      route: route ?? this.route,
      currentStep: currentStep ?? this.currentStep,
      nextStep: nextStep ?? this.nextStep,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      currentLegIndex: currentLegIndex ?? this.currentLegIndex,
      userPosition: userPosition ?? this.userPosition,
      isOverviewVisible: isOverviewVisible ?? this.isOverviewVisible,
      distanceToNextManeuver:
          distanceToNextManeuver ?? this.distanceToNextManeuver,
      remainingDistance: remainingDistance ?? this.remainingDistance,
      remainingDuration: remainingDuration ?? this.remainingDuration,
      isRerouting: isRerouting ?? this.isRerouting,
      hasAdvancedStep: hasAdvancedStep ?? this.hasAdvancedStep,
      isNavigationComplete: isNavigationComplete ?? this.isNavigationComplete,
      currentBearing: currentBearing ?? this.currentBearing,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      speedLimit: speedLimit ?? this.speedLimit,
      routeStartTime: routeStartTime ?? this.routeStartTime,
      actualAverageSpeed: actualAverageSpeed ?? this.actualAverageSpeed,
      expectedAverageSpeed: expectedAverageSpeed ?? this.expectedAverageSpeed,
      congestionNumericData:
          congestionNumericData ?? this.congestionNumericData,
      rerouteError: rerouteError ?? this.rerouteError,
    );
  }

  // Utility getters for UI
  String get formattedDistanceToManeuver =>
      MapboxNavigationUtils.formatDistance(distanceToNextManeuver);

  String get formattedRemainingDistance =>
      MapboxNavigationUtils.formatDistance(remainingDistance);

  String get formattedRemainingDuration =>
      MapboxNavigationUtils.formatDuration(remainingDuration);

  String get formattedETA => MapboxNavigationUtils.formatETA(remainingDuration);

  String get cleanedInstruction =>
      MapboxNavigationUtils.cleanInstruction(currentStep.maneuver.instruction);

  String? get roadName =>
      MapboxNavigationUtils.extractRoadName(currentStep.name);
}
