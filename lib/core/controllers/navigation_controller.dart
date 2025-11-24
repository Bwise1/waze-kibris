import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:waze_kibris/core/controllers/camera_controller.dart';
import 'package:waze_kibris/core/models/directions/mapbox_directions_response.dart';

enum NavigationStatus {
  idle,
  calculating,
  navigating,
  paused,
  completed,
  error,
}

class NavigationState {
  final NavigationStatus status;
  final MapboxRoute? route;
  final Position? currentPosition;
  final MapboxStep? currentStep;
  final int currentStepIndex;
  final int currentLegIndex;
  final double? remainingDistance;
  final double? remainingDuration;
  final double? distanceToNextManeuver;
  final bool isRerouting;
  final bool isOffRoute;
  final String? errorMessage;
  final double? currentSpeed;
  final double? currentBearing;

  const NavigationState({
    required this.status,
    this.route,
    this.currentPosition,
    this.currentStep,
    this.currentStepIndex = 0,
    this.currentLegIndex = 0,
    this.remainingDistance,
    this.remainingDuration,
    this.distanceToNextManeuver,
    this.isRerouting = false,
    this.isOffRoute = false,
    this.errorMessage,
    this.currentSpeed,
    this.currentBearing,
  });

  NavigationState copyWith({
    NavigationStatus? status,
    MapboxRoute? route,
    Position? currentPosition,
    MapboxStep? currentStep,
    int? currentStepIndex,
    int? currentLegIndex,
    double? remainingDistance,
    double? remainingDuration,
    double? distanceToNextManeuver,
    bool? isRerouting,
    bool? isOffRoute,
    String? errorMessage,
    double? currentSpeed,
    double? currentBearing,
  }) {
    return NavigationState(
      status: status ?? this.status,
      route: route ?? this.route,
      currentPosition: currentPosition ?? this.currentPosition,
      currentStep: currentStep ?? this.currentStep,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      currentLegIndex: currentLegIndex ?? this.currentLegIndex,
      remainingDistance: remainingDistance ?? this.remainingDistance,
      remainingDuration: remainingDuration ?? this.remainingDuration,
      distanceToNextManeuver: distanceToNextManeuver ?? this.distanceToNextManeuver,
      isRerouting: isRerouting ?? this.isRerouting,
      isOffRoute: isOffRoute ?? this.isOffRoute,
      errorMessage: errorMessage ?? this.errorMessage,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      currentBearing: currentBearing ?? this.currentBearing,
    );
  }

  factory NavigationState.idle() {
    return const NavigationState(status: NavigationStatus.idle);
  }

  factory NavigationState.calculating() {
    return const NavigationState(status: NavigationStatus.calculating);
  }

  factory NavigationState.navigating({
    required MapboxRoute route,
    Position? currentPosition,
  }) {
    return NavigationState(
      status: NavigationStatus.navigating,
      route: route,
      currentPosition: currentPosition,
      currentStep: route.legs.isNotEmpty && route.legs.first.steps.isNotEmpty
          ? route.legs.first.steps.first
          : null,
    );
  }

  factory NavigationState.completed({
    required MapboxRoute route,
    Position? currentPosition,
  }) {
    return NavigationState(
      status: NavigationStatus.completed,
      route: route,
      currentPosition: currentPosition,
    );
  }

  factory NavigationState.error(String errorMessage) {
    return NavigationState(
      status: NavigationStatus.error,
      errorMessage: errorMessage,
    );
  }
}

typedef OnNavigationStateChanged = void Function(NavigationState state);
typedef OnStepChanged = void Function(MapboxStep step);
typedef OnRouteRecalculationNeeded = Future<MapboxRoute?> Function(Position currentPosition);

class NavigationController {
  final CameraController _cameraController;
  final OnRouteRecalculationNeeded? _onRouteRecalculationNeeded;

  NavigationState _currentState = NavigationState.idle();
  StreamSubscription<Position>? _locationSubscription;

  static const double _stepAdvanceThreshold = 20.0;
  static const double _offRouteThreshold = 50.0;
  static const double _destinationReachedThreshold = 15.0;
  static const Duration _recalculationCooldown = Duration(seconds: 5);

  DateTime? _lastRecalculationTime;
  Position? _lastKnownGoodPosition;
  int _consecutiveOffRouteCount = 0;
  static const int _offRouteCountThreshold = 3;

  Position? _lastStateUpdatePosition;
  DateTime? _lastStateUpdateTime;
  static const double _minStateUpdateDistance = 2.0;
  static const Duration _minStateUpdateInterval = Duration(milliseconds: 500);

  final StreamController<NavigationState> _stateController =
      StreamController<NavigationState>.broadcast();
  final StreamController<MapboxStep> _stepController =
      StreamController<MapboxStep>.broadcast();

  OnNavigationStateChanged? onStateChanged;
  OnStepChanged? onStepChanged;

  NavigationController({
    required CameraController cameraController,
    OnRouteRecalculationNeeded? onRouteRecalculationNeeded,
    this.onStateChanged,
    this.onStepChanged,
  })  : _cameraController = cameraController,
        _onRouteRecalculationNeeded = onRouteRecalculationNeeded;

  NavigationState get currentState => _currentState;
  Stream<NavigationState> get stateStream => _stateController.stream;
  Stream<MapboxStep> get stepStream => _stepController.stream;

  bool get isNavigating => _currentState.status == NavigationStatus.navigating;
  bool get isCompleted => _currentState.status == NavigationStatus.completed;
  bool get isPaused => _currentState.status == NavigationStatus.paused;

  Future<void> startNavigation({
    required MapboxRoute route,
    required Stream<Position> locationStream,
  }) async {
    if (_currentState.status != NavigationStatus.idle) {
      throw StateError('Navigation already in progress');
    }

    _updateState(NavigationState.calculating());

    try {
      _cameraController.enableNavigationMode();

      _updateState(NavigationState.navigating(
        route: route,
        currentPosition: null,
      ));

      if (route.legs.isNotEmpty && route.legs.first.steps.isNotEmpty) {
        _stepController.add(route.legs.first.steps.first);
        onStepChanged?.call(route.legs.first.steps.first);
      }

      await _startLocationTracking(locationStream);
    } catch (e) {
      _updateState(NavigationState.error('Failed to start navigation: $e'));
      rethrow;
    }
  }

  Future<void> pauseNavigation() async {
    if (_currentState.status != NavigationStatus.navigating) return;

    await _stopLocationTracking();
    _updateState(_currentState.copyWith(status: NavigationStatus.paused));
  }

  Future<void> resumeNavigation(Stream<Position> locationStream) async {
    if (_currentState.status != NavigationStatus.paused) return;

    await _startLocationTracking(locationStream);
    _updateState(_currentState.copyWith(status: NavigationStatus.navigating));
  }

  Future<void> stopNavigation() async {
    await _stopLocationTracking();
    _cameraController.disableNavigationMode();
    _updateState(NavigationState.idle());
  }

  Future<void> updateRouteProgress({
    required Position currentPosition,
    int? currentStepIndex,
  }) async {
    if (_currentState.route == null) return;

    try {
      await _cameraController.updateCamera(
        userPosition: currentPosition,
        userBearing: currentPosition.heading >= 0 ? currentPosition.heading : null,
      );

      _updateState(NavigationState.navigating(
        route: _currentState.route!,
        currentPosition: currentPosition,
      ));
    } catch (e) {
      // Silently handle visualization errors
    }
  }

  Future<void> recalculateRoute(Position currentPosition) async {
    if (_currentState.route == null || _onRouteRecalculationNeeded == null) return;

    final now = DateTime.now();
    if (_lastRecalculationTime != null) {
      final timeSinceLastRecalc = now.difference(_lastRecalculationTime!);
      if (timeSinceLastRecalc < _recalculationCooldown) {
        return;
      }
    }

    try {
      _updateState(_currentState.copyWith(
        status: NavigationStatus.calculating,
        isRerouting: true,
      ));

      final newRoute = await _onRouteRecalculationNeeded!(currentPosition);

      if (newRoute != null) {
        _lastRecalculationTime = now;

        _updateState(NavigationState.navigating(
          route: newRoute,
          currentPosition: currentPosition,
        ));

        if (newRoute.legs.isNotEmpty && newRoute.legs.first.steps.isNotEmpty) {
          _stepController.add(newRoute.legs.first.steps.first);
          onStepChanged?.call(newRoute.legs.first.steps.first);
        }
      } else {
        _updateState(_currentState.copyWith(
          status: NavigationStatus.navigating,
          isRerouting: false,
        ));
      }
    } catch (e) {
      _updateState(_currentState.copyWith(
        status: NavigationStatus.error,
        errorMessage: 'Route recalculation failed: $e',
      ));
    }
  }

  Future<void> _startLocationTracking(Stream<Position> locationStream) async {
    _locationSubscription = locationStream.listen(
      _handleLocationUpdate,
      onError: (error) {
        _updateState(NavigationState.error('Location tracking error: $error'));
      },
    );
  }

  Future<void> _stopLocationTracking() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  Future<void> _handleLocationUpdate(Position position) async {
    if (!isNavigating || _currentState.route == null) return;

    if (!_isValidPosition(position)) return;

    final route = _currentState.route!;
    final currentLeg = route.legs.isNotEmpty && _currentState.currentLegIndex < route.legs.length
        ? route.legs[_currentState.currentLegIndex]
        : null;

    if (currentLeg == null) return;

    final currentStep = _currentState.currentStepIndex < currentLeg.steps.length
        ? currentLeg.steps[_currentState.currentStepIndex]
        : null;

    if (currentStep == null) {
      await _checkIfDestinationReached(position, route);
      return;
    }

    final distanceToStepEnd = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      currentStep.maneuver.location[1],
      currentStep.maneuver.location[0],
    );

    if (distanceToStepEnd <= _stepAdvanceThreshold) {
      await _advanceToNextStep(position);
      return;
    }

    if (_isOffRoute(position, currentStep)) {
      await _handleOffRoute(position);
      return;
    } else {
      _consecutiveOffRouteCount = 0;
      _lastKnownGoodPosition = position;
    }

    _updateNavigationProgress(position);
  }

  Future<void> _advanceToNextStep(Position position) async {
    if (_currentState.route == null) return;

    final route = _currentState.route!;
    final currentLeg = route.legs[_currentState.currentLegIndex];
    final nextStepIndex = _currentState.currentStepIndex + 1;

    if (nextStepIndex < currentLeg.steps.length) {
      final nextStep = currentLeg.steps[nextStepIndex];

      _updateState(_currentState.copyWith(
        currentStep: nextStep,
        currentStepIndex: nextStepIndex,
      ));

      _stepController.add(nextStep);
      onStepChanged?.call(nextStep);

      await _cameraController.updateCamera(
        userPosition: position,
        userBearing: position.heading >= 0 ? position.heading : null,
      );
    } else if (_currentState.currentLegIndex < route.legs.length - 1) {
      final nextLeg = route.legs[_currentState.currentLegIndex + 1];

      _updateState(_currentState.copyWith(
        currentStep: nextLeg.steps.first,
        currentStepIndex: 0,
        currentLegIndex: _currentState.currentLegIndex + 1,
      ));

      _stepController.add(nextLeg.steps.first);
      onStepChanged?.call(nextLeg.steps.first);
    } else {
      _updateState(NavigationState.completed(
        route: route,
        currentPosition: position,
      ));
    }

    _updateNavigationProgress(position);
  }

  Future<void> _handleOffRoute(Position position) async {
    _consecutiveOffRouteCount++;

    if (_consecutiveOffRouteCount < _offRouteCountThreshold) {
      await updateRouteProgress(
        currentPosition: position,
        currentStepIndex: _currentState.currentStepIndex,
      );
      return;
    }

    _consecutiveOffRouteCount = 0;
    await recalculateRoute(position);

    await _cameraController.update3DCamera(
      userPosition: position,
      userBearing: position.heading >= 0 ? position.heading : 0.0,
    );
  }

  Future<void> _checkIfDestinationReached(Position position, MapboxRoute route) async {
    if (route.legs.isEmpty) return;

    final lastLeg = route.legs.last;
    if (lastLeg.steps.isEmpty) return;

    final lastStep = lastLeg.steps.last;
    final distanceToDestination = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      lastStep.maneuver.location[1],
      lastStep.maneuver.location[0],
    );

    if (distanceToDestination <= _destinationReachedThreshold) {
      _updateState(NavigationState.completed(
        route: route,
        currentPosition: position,
      ));
    }
  }

  void _updateNavigationProgress(Position position) {
    if (_currentState.route == null) return;

    final shouldUpdateState = _shouldUpdateNavigationState(position);

    if (shouldUpdateState) {
      final route = _currentState.route!;
      final currentLeg = route.legs[_currentState.currentLegIndex];
      final currentStep = currentLeg.steps[_currentState.currentStepIndex];

      final distanceToNextManeuver = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        currentStep.maneuver.location[1],
        currentStep.maneuver.location[0],
      );

      final remainingDistance = _calculateRemainingDistance(position, route);
      final remainingDuration = _calculateRemainingDuration(remainingDistance, position.speed);

      _updateState(_currentState.copyWith(
        currentPosition: position,
        distanceToNextManeuver: distanceToNextManeuver,
        remainingDistance: remainingDistance,
        remainingDuration: remainingDuration,
        currentSpeed: position.speed,
        currentBearing: position.heading >= 0 ? position.heading : null,
      ));
    }

    _cameraController.updateCamera(
      userPosition: position,
      userBearing: position.heading >= 0 ? position.heading : null,
    );
  }

  bool _isOffRoute(Position position, MapboxStep currentStep) {
    if (currentStep.geometry.coordinates.isEmpty) return false;

    double minDistance = double.infinity;

    for (final coord in currentStep.geometry.coordinates) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        coord[1], // latitude
        coord[0], // longitude
      );
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    return minDistance > _offRouteThreshold;
  }

  double _calculateRemainingDistance(Position position, MapboxRoute route) {
    double totalDistance = 0.0;

    for (int legIndex = _currentState.currentLegIndex; legIndex < route.legs.length; legIndex++) {
      final leg = route.legs[legIndex];

      for (int stepIndex = (legIndex == _currentState.currentLegIndex ? _currentState.currentStepIndex : 0);
           stepIndex < leg.steps.length; stepIndex++) {
        final step = leg.steps[stepIndex];

        if (legIndex == _currentState.currentLegIndex && stepIndex == _currentState.currentStepIndex) {
          final distanceToStepEnd = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            step.maneuver.location[1],
            step.maneuver.location[0],
          );
          totalDistance += distanceToStepEnd;
        } else {
          totalDistance += step.distance;
        }
      }
    }

    return totalDistance;
  }

  double _calculateRemainingDuration(double remainingDistance, double? currentSpeed) {
    if (currentSpeed == null || currentSpeed <= 0) {
      return remainingDistance / 13.89; // Default 50 km/h
    }
    return remainingDistance / currentSpeed;
  }

  bool _shouldUpdateNavigationState(Position position) {
    final now = DateTime.now();

    if (_lastStateUpdatePosition == null || _lastStateUpdateTime == null) {
      _lastStateUpdatePosition = position;
      _lastStateUpdateTime = now;
      return true;
    }

    final timeSinceLastUpdate = now.difference(_lastStateUpdateTime!);
    if (timeSinceLastUpdate < _minStateUpdateInterval) {
      return false;
    }

    final distance = Geolocator.distanceBetween(
      _lastStateUpdatePosition!.latitude,
      _lastStateUpdatePosition!.longitude,
      position.latitude,
      position.longitude,
    );

    if (distance < _minStateUpdateDistance) {
      return false;
    }

    _lastStateUpdatePosition = position;
    _lastStateUpdateTime = now;
    return true;
  }

  bool _isValidPosition(Position position) {
    if (position.latitude.abs() > 90) return false;
    if (position.longitude.abs() > 180) return false;

    if (position.latitude.isNaN ||
        position.latitude.isInfinite ||
        position.longitude.isNaN ||
        position.longitude.isInfinite) {
      return false;
    }

    if (position.latitude == 0 && position.longitude == 0) {
      if (_lastKnownGoodPosition != null) {
        final distance = Geolocator.distanceBetween(
          _lastKnownGoodPosition!.latitude,
          _lastKnownGoodPosition!.longitude,
          0,
          0,
        );
        if (distance > 100000) return false;
      }
    }

    if (_lastKnownGoodPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastKnownGoodPosition!.latitude,
        _lastKnownGoodPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      final timeDiff = position.timestamp.difference(_lastKnownGoodPosition!.timestamp);
      if (timeDiff.inSeconds > 0) {
        final speed = distance / timeDiff.inSeconds;
        if (speed > 500) return false; // > 1800 km/h
      }
    }

    return true;
  }

  void _updateState(NavigationState newState) {
    _currentState = newState;
    _stateController.add(newState);
    onStateChanged?.call(newState);
  }

  Future<void> dispose() async {
    await _stopLocationTracking();

    if (!_stateController.isClosed) {
      await _stateController.close();
    }
    if (!_stepController.isClosed) {
      await _stepController.close();
    }
  }
}