# Native SDK Reference: Camera, Zoom, Puck — Translate to Dart

This document summarizes how **[mapbox-navigation-android](https://github.com/mapbox/mapbox-navigation-android)** and the **Mapbox Navigation iOS SDK** (camera options live in [mapbox-navigation-ios](https://github.com/mapbox/mapbox-navigation-ios); [mapbox-navigation-native-ios](https://github.com/mapbox/mapbox-navigation-native-ios) is the low-level core) handle camera, zoom, and location puck. Use it to align your Flutter app with native behavior.

---

## 1. Android: Viewport & camera options

**Source:** `ui-maps/.../camera/data/MapboxNavigationViewportDataSourceOptions.kt`

### Following frame (active navigation)

| Option | Default | Dart translation |
|--------|---------|------------------|
| **defaultPitch** | `45.0` | Use `45.0` for 3D follow; you currently use `0` (2D). Optional: add `pitchNearManeuvers` and keep 2D near turns. |
| **minZoom** | `10.5` | Clamp follow zoom to `>= 10.5`. |
| **maxZoom** | `16.35` | Clamp follow zoom to `<= 16.35`. Use as fallback when “zoom cannot be calculated precisely” (e.g. single point). |
| **focalPoint** | `(0.5, 1.0)` | User at bottom-center of padding (0.5 horizontal, 1.0 vertical from top). |
| **maximizeViewableGeometryWhenPitchZero** | `true` | When pitch is 0, frame geometry to maximize view (puck not fixed to bottom). |
| **centerUpdatesAllowed** | `true` | Allow center updates. |
| **zoomUpdatesAllowed** | `true` | Allow zoom updates. |
| **bearingUpdatesAllowed** | `true` | Allow bearing updates. |
| **pitchUpdatesAllowed** | `true` | Allow pitch updates. |

### Intersection density (zoom-in in urban, zoom-out on highway)

| Option | Default | Dart translation |
|--------|---------|------------------|
| **enabled** | `true` | Optionally shorten “geometry to frame” in dense intersections so zoom goes higher; use step geometry + average distance. |
| **averageDistanceMultiplier** | `7.0` | Multiplier for average intersection distance to get lookahead. |
| **minimumDistanceBetweenIntersections** | `20.0` (m) | Min distance to count two intersections separately. |

### Pitch near maneuver

| Option | Default | Dart translation |
|--------|---------|------------------|
| **enabled** | `true` | When distance to next maneuver ≤ threshold, set pitch to `0`. |
| **triggerDistanceFromManeuver** | `180.0` (m) | Use `distanceToManeuverAlongRouteMeters <= 180` → pitch 0. |
| **excludedManeuvers** | continue, merge, on ramp, off ramp, fork | Do not flatten pitch for these (optional to implement). |

### Frame geometry after maneuver

| Option | Default | Dart translation |
|--------|---------|------------------|
| **enabled** | `true` | Include points after the upcoming maneuver in the frame. |
| **distanceToCoalesceCompoundManeuvers** | `150.0` (m) | Distance to treat following maneuvers as one. |
| **distanceToFrameAfterManeuver** | `100.0` (m) | Extra distance after maneuver to include in frame. |

### Bearing smoothing

| Option | Default | Dart translation |
|--------|---------|------------------|
| **enabled** | `true` | Bearing blends location bearing with direction to upcoming geometry. |
| **maxBearingAngleDiff** | `45.0` (degrees) | Clamp map bearing deviation from raw course to ≤ 45°. |

### Overview frame

| Option | Default | Dart translation |
|--------|---------|------------------|
| **maxZoom** | `16.35` | Cap overview zoom at 16.35. |
| **geometrySimplification.enabled** | `true` | Use simplified route for overview (e.g. every Nth point). |
| **geometrySimplification.simplificationFactor** | `25` | Every 25th point + first/last per step. |

---

## 2. Android: Following camera framing strategy

**Source:** `ui-maps/.../camera/data/MapboxFollowingCameraFramingStrategy.kt`, `MapboxFollowingCameraFramingStrategy.kt`

- **Points to frame:** Current step remainder (from current position to end of step). Optionally shortened by intersection density: `lookaheadDistanceForZoom = distanceTraveledOnStep + (averageIntersectionDistance * averageDistanceMultiplier)` (default multiplier 7.0).
- **lineSliceAlong:** Uses Turf `lineSliceAlong` in km to slice step geometry for the lookahead segment.
- **maxAngleDifferenceForGeometrySlicing:** `100.0` degrees — slice at large angle changes.
- **Points after maneuver:** From precomputed `postManeuverFramingPoints` (distance after maneuver 100 m, coalesce 150 m).

**Dart:** Use your route geometry + snap index; slice from current position along the route for a “lookahead” segment (e.g. step remainder or intersection-based length). Frame that segment with `cameraForCoordinateBounds` and clamp zoom to `[10.5, 16.35]`.

---

## 3. Android: Location puck options

**Source:** `ui-maps/.../puck/LocationPuckOptions.kt`

- **States:** Separate puck per state: `freeDrivePuck`, `destinationPreviewPuck`, `routePreviewPuck`, `activeNavigationPuck`, `arrivalPuck`, `idlePuck`.
- **Default:** Same navigation puck (bearing image) for free drive, destination preview, route preview, active nav, and arrival; different “regular” puck (top + bearing + stroke) for IDLE and OVERVIEW.
- **Images:** Navigation uses `mapbox_navigation_puck_icon2` + shadow; regular uses Maps SDK `mapbox_user_icon`, `mapbox_user_bearing_icon`, `mapbox_user_stroke_icon`.
- No explicit zoom-based scale in this file; scaling often comes from the Maps SDK `LocationPuck2D` (e.g. scale expression).

**Dart:** You already have “normal” vs “navigation” puck. Optionally add distinct pucks for route preview and arrival; use the same asset as nav or a different one. Use zoom-based scale expression (e.g. 10 → 0.85, 14 → 1.0, 18 → 1.15, 22 → 1.2 for normal; keep/refine your nav puck expression).

---

## 4. Android: Viewport data source zoom usage

**Source:** `MapboxNavigationViewportDataSource.kt`

- **Following zoom:** From framed geometry; clamped to `minZoom` (10.5) and `maxZoom` (16.35). Fallback when there’s nothing to frame: `max(min(cameraState.zoom, maxZoom), minZoom)`.
- **When only location:** Uses `options.followingFrameOptions.maxZoom` and `defaultPitch`.
- **Overview:** Uses `overviewViewportDataSource`; overview max zoom 16.35.

---

## 5. iOS: Following camera options (Swift SDK)

**Source:** Mapbox docs + [mapbox-navigation-ios](https://github.com/mapbox/mapbox-navigation-ios) (not native-ios).

- **zoomRange:** `10.50...16.35` (ClosedRange). Same as Android min/max.
- **zoomUpdatesAllowed:** Can disable zoom updates.
- **Bearing smoothing:** `maximumBearingSmoothingAngle` (e.g. 45°).
- **Pitch near maneuver:** Pitch to 0 when within trigger distance (e.g. 180 m).
- **Geometry framing after maneuver:** Distance to frame after maneuver (e.g. 100 m).

So on both platforms: **follow zoom in [10.5, 16.35], pitch 45° by default, 0° near maneuver (180 m), bearing smoothing cap 45°.**

---

## 6. Dash (Android UX Framework) camera defaults

**Source:** [Mapbox docs – Camera](https://docs.mapbox.com/android/navigation/ux/guides/configuration/camera/)

- **freeDriveDefaults:** zoom 15.0, pitch 10.0  
- **tripPlanningDefaults:** zoom 17, pitch 0.0  
- **activeGuidanceDefaults:** zoom 17, pitch 45.0  
- **arrivalDefaults:** zoom 19, pitch 10.0  
- **lookAheadMeters:** default 1000 (in active guidance); set to 1.0 to avoid overriding zoom.

**Dart:** Use zoom 15 / pitch 0 (or 10) for free drive; 17 for route preview and active guidance baseline; 19 for arrival. Keep or add speed-based 14–17.5 for follow; clamp to 10.5–16.35 if you want to match the viewport data source exactly.

---

## 7. Constants to define in Dart

```dart
// Following (active guidance) — from MapboxNavigationViewportDataSourceOptions
const double kFollowingMinZoom = 10.5;
const double kFollowingMaxZoom = 16.35;
const double kFollowingDefaultPitch = 45.0;  // or 0 for 2D

// Pitch near maneuver
const double kPitchNearManeuverTriggerMeters = 180.0;

// Bearing smoothing
const double kBearingSmoothingMaxAngleDegrees = 45.0;

// Frame after maneuver
const double kDistanceToFrameAfterManeuverMeters = 100.0;
const double kDistanceToCoalesceCompoundManeuversMeters = 150.0;

// Intersection density (optional)
const double kIntersectionDensityMultiplier = 7.0;
const double kMinimumDistanceBetweenIntersectionsMeters = 20.0;

// Overview
const double kOverviewMaxZoom = 16.35;

// State-based (Dash-style) — optional
const double kFreeDriveZoom = 15.0;
const double kTripPlanningZoom = 17.0;
const double kActiveGuidanceZoom = 17.0;
const double kArrivalZoom = 19.0;
```

---

## 8. Translation checklist

- [ ] **Zoom range:** Clamp follow zoom to **10.5–16.35** (and optionally use 17 as initial when entering nav; 19 for arrival).
- [ ] **Pitch:** Default follow pitch **45°** if you want 3D; **0°** when `distanceToManeuverAlongRouteMeters <= 180`.
- [ ] **Bearing:** Apply **max 45°** deviation from raw course (bearing smoothing cap).
- [ ] **Overview:** Frame **remaining route** geometry; cap zoom at **16.35**; optionally simplify geometry (e.g. every 25th point).
- [ ] **Lookahead:** Frame **current step remainder** (or intersection-density–shortened segment) for following; use route geometry + snap index.
- [ ] **Puck:** Zoom-based scale for both normal and nav puck; optionally separate assets for idle/overview vs nav states.
- [ ] **Arrival:** When distance to destination &lt; threshold, switch to **zoom 19** (and optional arrival puck).

---

## 9. Destination arrival (trip complete)

**Sources:** [mapbox-navigation-android](https://github.com/mapbox/mapbox-navigation-android) (ArrivalObserver, RouteProgressState), [Mapbox Android arrival detection](https://docs.mapbox.com/android/navigation/guides/ui-components/arrival-detection/), [mapbox-navigation-ios](https://github.com/mapbox/mapbox-navigation-ios).

### Native behavior

- **Android:** Final destination arrival is reported when `RouteProgress.currentState == RouteProgressState.COMPLETE` and there are no more legs. The COMPLETE state is set by the core navigation engine using **along-route remaining distance** (snap-to-route + route geometry). Apps use `ArrivalObserver.onFinalDestinationArrival`. Arrival is only fired when state is `ROUTE_COMPLETE` or `LOCATION_TRACKING` (not during reroute/stale).
- **iOS:** `NavigationServiceDelegate` / `didArriveAt` when the user arrives at a waypoint or destination; driven by route progress (remaining distance) from the shared native core.

### Dart alignment

- Use **along-route remaining distance** from `SnapToRoadService` (`remainingDistanceAlongRouteMeters`) for “destination reached” when on the last step and not rerouting; threshold from `kDestinationReachedThresholdMeters` (e.g. 15 m).
- **Straight-line fallback:** Always treat as arrived when straight-line distance from current position to the final step’s maneuver location is below the same threshold (covers users who take another route but still reach the destination).
- **Guard:** Use along-route arrival only when not in reroute state; straight-line check can still set arrival when physically at destination.

Use this reference together with your existing [Native-Style Camera and Puck plan](.cursor/plans/native-style_camera_and_puck_b3c812cc.plan.md) (or `docs/` copy) to implement the Dart side.

---

## 10. Lane guidance

**Sources:** [mapbox-navigation-android](https://github.com/mapbox/mapbox-navigation-android) (MapboxManeuverView, MapboxLaneGuidance, ManeuverApi), [mapbox-navigation-ios](https://github.com/mapbox/mapbox-navigation-ios) (InstructionsBannerView, LanesView), [Directions API](https://docs.mapbox.com/api/navigation/directions/).

### Data source

- Lane data comes from the route step’s **intersections**: each intersection can have a `lanes` array with per-lane `active` (recommended), `valid` (usable), and `indications` (e.g. `"left"`, `"straight"`, `"right"`).
- Banner instructions provide *when* to show an instruction and primary/secondary/sub text; lane display is tied to the same step/intersection.

### When native shows lane guidance

- **Android:** Shown only when useful: multiple lanes and the upcoming maneuver requires a specific lane (MapboxManeuverView optional lane guidance).
- **iOS:** LanesView displays lane indications from the current visual instruction / intersection.

### Dart alignment

- **Model:** `MapboxIntersection.lanes` and `MapboxLane` (valid, active, indications) match the API.
- **Which intersection:** Use the intersection at the upcoming turn — i.e. the **last** intersection of the step that has lanes (maneuver is at end of step). Fallback: first intersection with lanes.
- **When to show:** Only when there are **multiple lanes** and **not all lanes have the same indications** (so guidance is useful). Hide for a single lane or when all lanes show the same maneuver options.
- **UI:** `LaneGuidanceWidget` in the maneuver banner: lane strip with indication arrows and active/valid/invalid styling.
- **Map layer:** Lane guidance can be drawn on the map (e.g. near the upcoming intersection); placement strategy: use current step’s maneuver intersection location. Currently disabled; re-enable with that placement if desired.
