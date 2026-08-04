part of 'navigation_bloc.dart';

abstract class NavigationEvent extends Equatable {
  const NavigationEvent();

  @override
  List<Object> get props => [];
}

class NavigationStarted extends NavigationEvent {
  final MapboxRoute route;
  final TravelMode mode;

  const NavigationStarted({required this.route, this.mode = TravelMode.drive});

  @override
  List<Object> get props => [route, mode];
}

class NavigationPositionUpdated extends NavigationEvent {
  final Position position;
  /// When provided, bloc uses these for progress/voice/step/off-route (native SDK parity).
  final double? distanceToManeuverAlongRouteMeters;
  final double? remainingDistanceAlongRouteMeters;
  final bool? isOffRouteFromSnap;
  final bool? needsRerouteFromSnap;

  const NavigationPositionUpdated({
    required this.position,
    this.distanceToManeuverAlongRouteMeters,
    this.remainingDistanceAlongRouteMeters,
    this.isOffRouteFromSnap,
    this.needsRerouteFromSnap,
  });

  @override
  List<Object> get props => [
        position,
        distanceToManeuverAlongRouteMeters ?? -1.0,
        remainingDistanceAlongRouteMeters ?? -1.0,
        isOffRouteFromSnap ?? false,
        needsRerouteFromSnap ?? false,
      ];
}

class NavigationStopped extends NavigationEvent {}

class NavigationOverviewToggled extends NavigationEvent {}

class NavigationStepCompleted extends NavigationEvent {}

class NavigationRerouteRequested extends NavigationEvent {}

class ClearRerouteError extends NavigationEvent {}
