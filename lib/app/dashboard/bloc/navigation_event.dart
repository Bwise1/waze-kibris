part of 'navigation_bloc.dart';

abstract class NavigationEvent extends Equatable {
  const NavigationEvent();

  @override
  List<Object> get props => [];
}

class NavigationStarted extends NavigationEvent {
  final DirectionsRoute route;

  const NavigationStarted({required this.route});

  @override
  List<Object> get props => [route];
}

class NavigationPositionUpdated extends NavigationEvent {
  final Position position;

  const NavigationPositionUpdated({required this.position});

  @override
  List<Object> get props => [position];
}

class NavigationStopped extends NavigationEvent {}

class NavigationOverviewToggled extends NavigationEvent {}

class NavigationStepCompleted extends NavigationEvent {}

class NavigationRerouteRequested extends NavigationEvent {}
