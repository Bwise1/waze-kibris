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
  final TravelMode mode;
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
    this.mode = TravelMode.drive,
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
        mode,
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
        // congestionNumericData intentionally omitted from props: it's a
        // 350+ element list that Equatable would deep-compare on every fix.
        // Congestion only changes on (re)route, and `route` above already
        // covers that identity — a new list arrives only with a new route.
        rerouteError,
      ];

  NavigationInProgress copyWith({
    MapboxRoute? route,
    TravelMode? mode,
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
      mode: mode ?? this.mode,
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

/// Per-fix subset of [NavigationInProgress] that drives banner/speedometer/
/// progress. Extracted so leaf widgets subscribe to a small equatable value
/// via `BlocSelector`, and only rebuild when a displayed number actually
/// changes — instead of re-running on every GPS fix because e.g. `userPosition`
/// churned.
class NavTelemetry extends Equatable {
  const NavTelemetry({
    required this.distanceToNextManeuver,
    required this.remainingDistance,
    required this.remainingDuration,
    required this.currentSpeed,
    required this.speedLimit,
    required this.currentStepIndex,
    required this.isRerouting,
    required this.hasCongestionData,
    this.currentStep,
    this.nextStep,
    this.rerouteError,
  });

  final double distanceToNextManeuver;
  final double remainingDistance;
  final double remainingDuration;
  final double? currentSpeed;
  final double? speedLimit;
  final int currentStepIndex;
  final bool isRerouting;
  // Presence-only: the overlay just shows a traffic icon if any congestion
  // data exists. Reading the flag here keeps the full list out of `props`
  // (which would deep-compare a 350+ element list per fix).
  final bool hasCongestionData;

  // The step objects the banner renders. These MUST come through telemetry,
  // not the outer builder's captured state: the phase-gated builder stops
  // re-running per fix, so a captured NavigationInProgress freezes at
  // phase-change time — which froze the instruction banner on the first
  // turn. MapboxStep has no ==, and copyWith reuses the instance between
  // advances, so identity equality here means "rebuild exactly when the
  // step actually changes".
  final MapboxStep? currentStep;
  final MapboxStep? nextStep;

  // Same stale-capture trap: a FAILED reroute sets this without swapping
  // the route object, so nothing phase-gated ever re-renders it.
  final String? rerouteError;

  factory NavTelemetry.from(NavigationInProgress s) => NavTelemetry(
        distanceToNextManeuver: s.distanceToNextManeuver,
        remainingDistance: s.remainingDistance,
        remainingDuration: s.remainingDuration,
        currentSpeed: s.currentSpeed,
        speedLimit: s.speedLimit,
        currentStepIndex: s.currentStepIndex,
        isRerouting: s.isRerouting,
        hasCongestionData: s.congestionNumericData?.isNotEmpty ?? false,
        currentStep: s.currentStep,
        nextStep: s.nextStep,
        rerouteError: s.rerouteError,
      );

  @override
  List<Object?> get props => [
        distanceToNextManeuver,
        remainingDistance,
        remainingDuration,
        currentSpeed,
        speedLimit,
        currentStepIndex,
        isRerouting,
        hasCongestionData,
        currentStep,
        nextStep,
        rerouteError,
      ];
}
