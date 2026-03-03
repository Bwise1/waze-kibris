import 'dart:async';
import 'dart:developer' as developer;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:waze_kibris/core/models/directions/mapbox_directions_response.dart';
import 'package:waze_kibris/app/dashboard/services/voice_instruction_service.dart';
import 'package:waze_kibris/app/dashboard/view/mapbox_navigation_utils.dart';

class EnhancedNavigationController {
  static final EnhancedNavigationController _instance =
      EnhancedNavigationController._internal();
  factory EnhancedNavigationController() => _instance;
  EnhancedNavigationController._internal();

  // Services
  final VoiceInstructionService _voiceService = VoiceInstructionService();

  // Navigation state
  MapboxRoute? _currentRoute;
  int _currentStepIndex = 0;
  double _distanceRemaining = 0;
  Position? _currentPosition;
  Timer? _navigationTimer;

  // Callbacks for UI updates
  Function(MapboxStep step, double distanceRemaining)? onStepUpdate;
  Function(MapboxBannerInstruction? banner)? onBannerUpdate;
  Function()? onDestinationReached;
  Function(MapboxRoute route)? onOffRoute;

  bool get isNavigating => _navigationTimer != null;
  MapboxStep? get currentStep => _currentRoute != null &&
          _currentStepIndex < _currentRoute!.legs.first.steps.length
      ? _currentRoute!.legs.first.steps[_currentStepIndex]
      : null;

  Future<void> initialize() async {
    await _voiceService.initialize();
    developer.log('Enhanced navigation controller initialized',
        name: 'NavigationController');
  }

  Future<void> dispose() async {
    await stopNavigation();
    await _voiceService.dispose();
  }

  // Start navigation with enhanced features
  Future<void> startNavigation(MapboxRoute route) async {
    _currentRoute = route;
    _currentStepIndex = 0;
    _distanceRemaining = route.distance;

    // Reset voice service for new navigation
    _voiceService.reset();

    // Start location tracking timer
    _navigationTimer =
        Timer.periodic(const Duration(seconds: 1), _onNavigationTimer);

    developer.log('Enhanced navigation started', name: 'NavigationController');

    // Immediate update
    _updateNavigationState();
  }

  Future<void> stopNavigation() async {
    _navigationTimer?.cancel();
    _navigationTimer = null;
    _currentRoute = null;
    _currentStepIndex = 0;
    _distanceRemaining = 0;

    await _voiceService.stop();

    developer.log('Enhanced navigation stopped', name: 'NavigationController');
  }

  void updateCurrentPosition(Position position) {
    _currentPosition = position;
    _updateNavigationState();
  }

  void _onNavigationTimer(Timer timer) {
    if (_currentPosition != null) {
      _updateNavigationState();
    }
  }

  void _updateNavigationState() {
    if (_currentRoute == null || currentStep == null) return;

    final step = currentStep!;

    // Calculate distance to current step's maneuver
    if (_currentPosition != null) {
      _distanceRemaining = MapboxNavigationUtils.calculateDistanceMeters(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        LatLng(step.maneuver.location[1], step.maneuver.location[0]),
      );
    }

    // Check if we should advance to next step
    if (_shouldAdvanceStep()) {
      _advanceToNextStep();
      return;
    }

    // Check if destination reached
    if (_isDestinationReached()) {
      _onDestinationReached();
      return;
    }

    // Process voice instructions for current step
    _processVoiceInstructions(step);

    // Update banner instructions
    _processBannerInstructions(step);

    // Notify UI of step update
    onStepUpdate?.call(step, _distanceRemaining);
  }

  bool _shouldAdvanceStep() {
    if (_currentPosition == null || currentStep == null) return false;

    final step = currentStep!;
    final userLocation =
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude);

    // Check if user is close to the maneuver point
    return MapboxNavigationUtils.isUserNearPoint(
      userLocation,
      LatLng(step.maneuver.location[1], step.maneuver.location[0]),
      thresholdMeters: MapboxNavigationUtils.stepAdvanceThreshold,
    );
  }

  void _advanceToNextStep() {
    if (_currentRoute == null) return;

    _currentStepIndex++;

    if (_currentStepIndex >= _currentRoute!.legs.first.steps.length) {
      // Navigation complete
      _onDestinationReached();
      return;
    }

    developer.log('Advanced to step ${_currentStepIndex + 1}',
        name: 'NavigationController');

    // Update with new step
    _updateNavigationState();
  }

  bool _isDestinationReached() {
    if (_currentPosition == null || _currentRoute == null) return false;

    final lastStep = _currentRoute!.legs.first.steps.last;
    final userLocation =
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    final destination =
        LatLng(lastStep.maneuver.location[1], lastStep.maneuver.location[0]);

    return MapboxNavigationUtils.isUserNearPoint(
      userLocation,
      destination,
      thresholdMeters: MapboxNavigationUtils.destinationReachedThreshold,
    );
  }

  void _onDestinationReached() {
    developer.log('Destination reached!', name: 'NavigationController');
    onDestinationReached?.call();
    stopNavigation();
  }

  Future<void> _processVoiceInstructions(MapboxStep step) async {
    await _voiceService.processVoiceInstructions(step, _distanceRemaining);
  }

  void _processBannerInstructions(MapboxStep step) {
    if (step.bannerInstructions.isEmpty) {
      onBannerUpdate?.call(null);
      return;
    }

    // Find appropriate banner based on distance remaining
    MapboxBannerInstruction? currentBanner;

    for (final banner in step.bannerInstructions) {
      if (_distanceRemaining >= banner.distanceAlongGeometry) {
        currentBanner = banner;
        break;
      }
    }

    // Use first banner as fallback
    currentBanner ??= step.bannerInstructions.first;

    onBannerUpdate?.call(currentBanner);
  }

  // Manual voice trigger
  Future<void> speakCurrentInstruction() async {
    if (currentStep != null) {
      await _voiceService.speakCurrentInstruction(currentStep!);
    }
  }

  // Voice settings
  bool get isVoiceEnabled => _voiceService.isEnabled;
  set isVoiceEnabled(bool enabled) => _voiceService.isEnabled = enabled;

  Future<void> setVoiceLanguage(String language) async {
    await _voiceService.setLanguage(language);
  }

  Future<void> setVoiceSpeechRate(double rate) async {
    await _voiceService.setSpeechRate(rate);
  }

  Future<void> setVoiceVolume(double volume) async {
    await _voiceService.setVolume(volume);
  }

  Future<void> testVoice() async {
    await _voiceService.testSpeech();
  }

  // Navigation info getters
  double get distanceRemaining => _distanceRemaining;
  int get currentStepIndex => _currentStepIndex;
  int get totalSteps => _currentRoute?.legs.first.steps.length ?? 0;

  String get formattedDistanceRemaining =>
      MapboxNavigationUtils.formatDistance(_distanceRemaining);

  String get estimatedTimeRemaining {
    if (_currentRoute == null || _currentPosition == null) return '';

    final remainingSteps =
        _currentRoute!.legs.first.steps.skip(_currentStepIndex).toList();

    // Get congestion data from route annotations if available
    final congestionData =
        _currentRoute!.legs.first.annotations?.congestionNumeric;
    final expectedAverageSpeed = _currentRoute!.legs.first.averageSpeed;

    final remainingTime = MapboxNavigationUtils.calculateRemainingTime(
      _distanceRemaining,
      _currentPosition!.speed,
      remainingSteps,
      congestionNumericData: congestionData,
      actualAverageSpeed: null, // Not tracked in this controller
      expectedAverageSpeed: expectedAverageSpeed,
    );

    return MapboxNavigationUtils.formatDuration(remainingTime);
  }

  String get estimatedArrivalTime {
    if (_currentRoute == null) return '';

    final remainingSteps =
        _currentRoute!.legs.first.steps.skip(_currentStepIndex).toList();

    final remainingTime =
        remainingSteps.fold(0.0, (total, step) => total + step.duration);

    return MapboxNavigationUtils.formatETA(remainingTime);
  }
}
