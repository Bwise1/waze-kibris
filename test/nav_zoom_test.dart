import 'package:flutter_test/flutter_test.dart';
import 'package:waze_kibris/core/constants/navigation_camera_constants.dart';
import 'package:waze_kibris/core/models/navigation/travel_mode.dart';

/// The driving zoom curve, mirrored from _updateNavigationCamera.
double driveTargetZoom(double speedKmh) {
  double z;
  if (speedKmh < 30) {
    z = 17.5;
  } else if (speedKmh > 100) {
    z = 14.0;
  } else {
    final t = (speedKmh - 30) / (100 - 30);
    z = 17.5 - (t * (17.5 - 14.0));
  }
  return z.clamp(kFollowingMinZoom, kFollowingMaxZoom);
}

void main() {
  test('the follow clamp does not silently override the curve', () {
    // The bug: kFollowingMaxZoom was 16.35, below the curve's slow end of
    // 17.5, so crawling traffic was clipped and the camera converged to
    // 16.35 on every trip instead of the zoom the curve asked for.
    expect(driveTargetZoom(0), 17.5);
    expect(driveTargetZoom(20), 17.5);
  });

  test('fast driving still zooms out', () {
    expect(driveTargetZoom(120), 14.0);
    expect(driveTargetZoom(65), closeTo(15.75, 0.01));
  });

  test('drive mode can reach its own activeGuidanceZoom', () {
    // A ceiling below the mode's stated preference means the preference is
    // a lie. Walk/cycle bypass the clamp, so only drive is asserted here.
    expect(TravelMode.drive.activeGuidanceZoom,
        lessThanOrEqualTo(kFollowingMaxZoom));
  });

  test('arrival zoom stays where street labels still render', () {
    // Past ~z18.5 Mapbox drops street names and you get bare building
    // blocks — which is what prompted this change.
    expect(kArrivalZoom, lessThanOrEqualTo(18.0));
    expect(kArrivalZoom, greaterThan(kFollowingMaxZoom));
  });
}
