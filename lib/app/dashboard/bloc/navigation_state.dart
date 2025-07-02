// Enhanced NavigationState with additional fields for better camera tracking
part of 'navigation_bloc.dart';

abstract class NavigationState extends Equatable {
  const NavigationState();

  @override
  List<Object?> get props => [];
}

class NavigationInitial extends NavigationState {}

class NavigationInProgress extends NavigationState {
  final DirectionsRoute route;
  final DirectionsStep currentStep;
  final int currentStepIndex;
  final int currentLegIndex;
  final Position? userPosition;
  final bool isOverviewVisible;
  final int distanceToNextManeuver;
  final int remainingDistance;
  final int remainingDuration;
  final bool isRerouting;
  final bool hasAdvancedStep;
  final bool isNavigationComplete;
  final double? currentBearing; // Added for camera tracking
  final double? currentSpeed; // Added for speed tracking

  const NavigationInProgress({
    required this.route,
    required this.currentStep,
    required this.currentStepIndex,
    required this.currentLegIndex,
    this.userPosition,
    this.isOverviewVisible = false,
    this.distanceToNextManeuver = 0,
    required this.remainingDistance,
    required this.remainingDuration,
    this.isRerouting = false,
    this.hasAdvancedStep = false,
    this.isNavigationComplete = false,
    this.currentBearing,
    this.currentSpeed,
  });

  @override
  List<Object?> get props => [
        route,
        currentStep,
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
      ];

  NavigationInProgress copyWith({
    DirectionsRoute? route,
    DirectionsStep? currentStep,
    int? currentStepIndex,
    int? currentLegIndex,
    Position? userPosition,
    bool? isOverviewVisible,
    int? distanceToNextManeuver,
    int? remainingDistance,
    int? remainingDuration,
    bool? isRerouting,
    bool? hasAdvancedStep,
    bool? isNavigationComplete,
    double? currentBearing,
    double? currentSpeed,
  }) {
    return NavigationInProgress(
      route: route ?? this.route,
      currentStep: currentStep ?? this.currentStep,
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
    );
  }

  // Utility getters for UI
  String get formattedDistanceToManeuver =>
      NavigationUtils.formatDistance(distanceToNextManeuver);

  String get formattedRemainingDistance =>
      NavigationUtils.formatDistance(remainingDistance);

  String get formattedRemainingDuration =>
      NavigationUtils.formatDuration(remainingDuration);

  String get formattedETA => NavigationUtils.formatETA(remainingDuration);

  String get cleanedInstruction =>
      NavigationUtils.cleanInstruction(currentStep.htmlInstr);

  String? get roadName =>
      NavigationUtils.extractRoadName(currentStep.htmlInstr);
}
