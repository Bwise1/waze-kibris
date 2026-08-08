/// Native-style camera and viewport constants (Mapbox Navigation Android/iOS).
/// See docs/native_camera_puck_reference.md for sources.
library;

// Following (active guidance) — MapboxNavigationViewportDataSourceOptions
const double kFollowingMinZoom = 10.5;

/// Ceiling for the follow camera.
///
/// Was 16.35, which sat *below* drive mode's own activeGuidanceZoom of 17.0
/// — so the clamp silently overrode the mode's preference and the camera
/// converged to 16.35 on every trip (visible in the nav traces, where
/// zoomTarget sat at 16.35 while drive mode asked for 17.0). 17.5 leaves
/// headroom for the speed-based curve's slow end without letting the map
/// zoom past the point where street labels stop rendering.
const double kFollowingMaxZoom = 17.5;
/// Default pitch during follow. Native Mapbox default is 45° — gives the 3D
/// "looking down the road" perspective that makes turn-by-turn feel like
/// Google/Apple/Waze instead of a flat 2D map.
const double kFollowingDefaultPitch = 45.0;

// Pitch near maneuver — flatten camera when within this distance of next
// turn so the driver can see the whole intersection top-down. 180m is far
// too aggressive for city driving (you're within 180m of a turn ~90% of
// the time and the camera never gets to 3D). Native uses ~30m.
const double kPitchNearManeuverTriggerMeters = 30.0;

/// Pitch value used when close to a maneuver. Not fully flat (0°) — a slight
/// tilt keeps some 3D context so the camera transition doesn't feel like a
/// jarring "collapse to 2D" every 30m before every turn.
const double kPitchNearManeuverValue = 20.0;

// Bearing smoothing — max deviation from raw course (degrees)
const double kBearingSmoothingMaxAngleDegrees = 45.0;

// Overview
const double kOverviewDefaultZoom = 14.0;
const double kOverviewMaxZoom = 16.35;

// Arrival — zoom in when remaining distance below threshold

/// Zoom used on arrival.
///
/// Was 19.0, which at this latitude shows only ~120m across the screen —
/// close enough that Mapbox drops street name labels and you get bare
/// building footprints with no writing. 18.0 shows ~240m: still tight
/// enough to see which side of the street you're on and where the entrance
/// is, but the roads are still named.
const double kArrivalZoom = 18.0;
const double kArrivalRemainingDistanceThresholdMeters = 100.0;

// State-based (Dash-style) initial zoom
const double kFreeDriveZoom = 15.0;
const double kActiveGuidanceZoom = 17.0;

// Destination reached — trip complete when remaining along route or straight-line to destination below this (meters)
const double kDestinationReachedThresholdMeters = 15.0;
