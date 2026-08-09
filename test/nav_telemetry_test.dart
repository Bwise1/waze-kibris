import 'package:flutter_test/flutter_test.dart';
import 'package:waze_kibris/app/dashboard/bloc/navigation_bloc.dart';
import 'package:waze_kibris/core/models/directions/mapbox_directions_response.dart';

/// The dashboard's outer builder is phase-gated: it does NOT re-run per GPS
/// fix. Every per-fix thing the overlay renders must therefore travel
/// through NavTelemetry — anything read off the captured NavigationInProgress
/// freezes at phase-change time. The refactor shipped with the banner steps,
/// reroute error and report position all captured stale; these tests pin the
/// contract that keeps them live.
void main() {
  MapboxStep step(String name) => MapboxStep(
        intersections: [],
        geometry: MapboxLineString(type: 'LineString', coordinates: []),
        maneuver: MapboxManeuver(
          type: 'turn',
          instruction: 'Turn right',
          bearingAfter: 90,
          bearingBefore: 0,
          location: [0.0, 0.0],
          modifier: 'right',
        ),
        name: name,
        duration: 60,
        distance: 100,
        mode: 'driving',
      );

  NavigationInProgress state(MapboxStep current, {String? rerouteError}) =>
      NavigationInProgress(
        route: MapboxRoute(
          geometry: MapboxLineString(type: 'LineString', coordinates: []),
          legs: [],
          weightName: 'auto',
          weight: 1,
          duration: 600,
          distance: 1000,
        ),
        currentStep: current,
        currentStepIndex: 0,
        currentLegIndex: 0,
        remainingDistance: 900,
        remainingDuration: 500,
        rerouteError: rerouteError,
      );

  test('telemetry carries the banner steps and reroute error', () {
    final s = state(step('A'), rerouteError: 'no route');
    final t = NavTelemetry.from(s);
    expect(t.currentStep, same(s.currentStep),
        reason: 'banner must render the step from telemetry, not stale state');
    expect(t.rerouteError, 'no route');
  });

  test(
      'same step instance -> equal telemetry (no wasted rebuilds); '
      'advanced step -> unequal (banner updates)', () {
    final shared = step('A');
    final t1 = NavTelemetry.from(state(shared));
    final t2 = NavTelemetry.from(state(shared));
    expect(t1, t2,
        reason: 'copyWith reuses the step instance between advances — '
            'identity equality must hold or the overlay rebuilds per fix '
            'for nothing');

    final t3 = NavTelemetry.from(state(step('B')));
    expect(t1 == t3, isFalse,
        reason: 'a new step instance is exactly the moment the banner '
            'must re-render');
  });
}
