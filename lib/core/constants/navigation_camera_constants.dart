/// Native-style camera and viewport constants (Mapbox Navigation Android/iOS).
/// See docs/native_camera_puck_reference.md for sources.
library;

// Following (active guidance) — MapboxNavigationViewportDataSourceOptions
const double kFollowingMinZoom = 10.5;
const double kFollowingMaxZoom = 16.35;
/// Default pitch during follow. Use 0 for 2D (Waze-style); native uses 45.0 for 3D.
const double kFollowingDefaultPitch = 0.0;

// Pitch near maneuver — flatten to 0° when within this distance of next turn
const double kPitchNearManeuverTriggerMeters = 180.0;

// Bearing smoothing — max deviation from raw course (degrees)
const double kBearingSmoothingMaxAngleDegrees = 45.0;

// Overview
const double kOverviewDefaultZoom = 14.0;
const double kOverviewMaxZoom = 16.35;

// Arrival — zoom in when remaining distance below threshold
const double kArrivalZoom = 19.0;
const double kArrivalRemainingDistanceThresholdMeters = 100.0;

// State-based (Dash-style) initial zoom
const double kFreeDriveZoom = 15.0;
const double kActiveGuidanceZoom = 17.0;

// Destination reached — trip complete when remaining along route or straight-line to destination below this (meters)
const double kDestinationReachedThresholdMeters = 15.0;
