# Mapbox Native Navigation SDK — Extracted Reference

Extracted 2026-08-05 from the official SDK sources (no guesswork; every value read
from code):
- `mapbox/mapbox-navigation-android` @ `84267e9` (v3.29.0-SNAPSHOT) — `ui-maps`, `voice`, `navigation`, `tripdata`
- `mapbox/mapbox-navigation-ios` @ `905f270` (v3.x, `MapboxNavigationCore` + `MapboxNavigationUIKit`)

File:line citations refer to those repos. Items marked **[closed]** live in the
closed nav-native binary and cannot be copied — our own implementation stands.

---

## 1. Camera — following mode

### Core constants (identical on both platforms)

| Constant | Value | Source |
|---|---|---|
| Default pitch | **45.0°** | And `MapboxNavigationViewportDataSourceOptions.kt:32`, iOS `FollowingCameraOptions.swift:14` |
| Zoom clamp | **[10.5, 16.35]** | And :39,:49; iOS :36 |
| Overview max zoom | **16.35** | And :347 |
| Pitch→0 trigger distance | **180 m before maneuver** (linear ramp on iOS: `pitch = 45 * distanceRemaining/180`) | And :217, iOS `ViewportDataSource+Calculation.swift:102-130` |
| Maneuvers that do NOT trigger pitch-down | `continue, merge, on ramp, off ramp, fork` (+ the final step) | And :226-232, iOS same list |
| Bearing smoothing max deviation | **±45°** from GPS course | And :289, iOS `FollowingCameraOptions.swift:194` |
| Look-ahead distance | avg intersection spacing on current step (gaps ≤20 m filtered) × **7.0** | And :184,:193; iOS `IntersectionDensity` |
| Post-maneuver framing | next step trimmed to **100 m**; compound steps coalesced up to **150 m** | And :257,:267; iOS `GeometryFramingAfterManeuver` |
| Puck anchor (focal point) | **(0.5, 1.0)** — horizontally centered on the BOTTOM edge of the padding rect | And :65 |
| iOS default viewport padding | safeArea + `(top 20, left 20, bottom 40, right 20)` | `NavigationMapView.swift:13,:413` |
| Android demo app following padding (portrait, dp) | `(top 180, left 40, bottom 150, right 40)` | `NavigationStateVisualizationActivity.kt:55-84` |

### How zoom is actually computed (NOT speed-based!)

Native never maps speed→zoom. Zoom comes from **framing the road ahead**:

1. Slice the current step's remaining geometry from the puck to
   `lookahead = avgIntersectionGap × 7.0` meters ahead
   (`MapboxFollowingCameraFramingStrategy.kt:66-112`).
   Cut the slice at the first vertex whose edge bearing deviates >100° from the
   first edge (stops framing past a U-turn).
2. Within 180 m of a (non-excluded) maneuver, append the post-maneuver geometry
   (100 m of next step + compound steps ≤150 m).
3. `zoom = cameraForCoordinates(points, padding, bearing, pitch)` fitted into the
   padded screen box, clamped to [10.5, 16.35].

Dense city streets ⇒ short look-ahead ⇒ high zoom; open highway ⇒ long look-ahead
⇒ low zoom. Speed correlates but is not the input.

### How bearing is computed

`geoBearing = bearing(firstPoint → lastPoint of the look-ahead slice)`.
If `|geoBearing − gpsCourse| > 45°` ⇒ use `gpsCourse ± 45°`, else use `geoBearing`.
Then unwrap relative to the *current camera bearing* so rotation always takes the
short way (And `ViewportDataSourceProcessor.kt:346-369`, iOS
`ViewportDataSource+Calculation.swift:8-32`). No low-pass filter, no time constant.
Walking mode uses compass heading instead.

### The animation model (the "native feel" secret)

- **Android**: every location fix triggers a **1000 ms, TRUE LINEAR**
  (`PathInterpolator(0,0,1,1)`) animation of center/zoom/bearing/pitch/padding —
  all same duration, no delay (`DefaultSimplifiedUpdateFrameTransitionProvider.kt:103-104`).
  The puck animates with the **same 1000 ms** duration and a shared
  constant-velocity interpolator (`NavigationLocationProvider.kt:81,:167-189`;
  `DEFAULT_INTERVAL_MILLIS = 1000`). Camera and puck are in exact lockstep.
- **iOS**: camera options are throttled to **5 Hz** (0.2 s,
  `NavigationCamera.swift:92`) and each update animates with a **1.0 s LINEAR
  cubic (0,0)→(1,1)** `UIViewPropertyAnimator`
  (`NavigationCameraStateTransition.swift:77-84`). Each new update interrupts the
  previous animator mid-flight ⇒ continuous motion.
- Deadbands (iOS, following only): center 2 px, bearing 1°, pitch 1°.
- State transitions (idle→following etc.): iOS `fly(to:)` 0.5 s (zoom in) / 0.25 s
  (zoom out). Android: per-property animators with `(0.4, 0, 0.4, 1)` easing —
  zoom 1800 ms, bearing 1200 ms delay 600, center 1000 ms delay 800, pitch
  1000 ms, padding 1200 ms; whole set scaled to `maxDuration = 3500 ms`.
- **KEY LESSON**: per-fix updates use LINEAR easing, never ease-in-out. Chained
  ease-in-out animations pulse (slow-fast-slow every second).

### Gestures / state machine

- Any pan/rotate/pitch/quick-zoom → idle. On Android, **pinch-zoom does NOT exit
  follow mode** (`NavigationScaleGestureHandler.kt:169-197`); the gesture focal
  point is pinned to the puck and fling is disabled while following.
- Thresholds while following (Android): pan 25 dp, multi-finger move 400 dp,
  rotation 5°.
- Neither SDK has an auto-recenter timeout — re-follow is explicit (button).
- Frame updates are dropped during transitions and in idle.
- Arrival/free-drive: pitch 0, zoom from 1700 m altitude, centered puck,
  safe-area padding only (iOS `MobileViewportDataSource.swift:74-110`).

### Camera input position **[closed-adjacent but verified]**

The camera and puck consume the **map-matched (snapped) location** produced by
nav-native (`MapboxNavigator.swift:105`), not raw GPS.

---

## 2. Route line

### Colors (identical traffic palette on both platforms)

| Element | Hex | Source |
|---|---|---|
| Main route / traffic low / unknown | `#56A8FB` | And `RouteLayerConstants.kt:111-117`, iOS `UIColor++.swift` |
| Casing | `#2F7AC6` | And :144 |
| Traffic moderate | `#F5C32E` | :120 |
| Traffic heavy | `#F54724` | :123 |
| Traffic severe | `#C32828` | :126 |
| Traveled portion | **transparent** (Android) / optional grey `traversedRoute` layer (iOS) | And :105-108 |
| Alternative route | And `#8694A5` (casing `#727E8D`) / iOS `#999999` (casing `#807F80`) | :147-150 |
| Maneuver arrow | shaft `#FFFFFF`, casing `#054AAD` (And) / stroke `#56A8FB` (iOS) | :183-186 |
| Restricted road | `#000000`, dash `[0.5, 2.0]`, width 7 | :99-101,:168 |

### Width — zoom-interpolated, exponential base 1.5 (Android)

`["interpolate", ["exponential", 1.5], ["zoom"], stops...]`
(`MapboxRouteLineUtils.kt:1217-1231`):
- Main + traffic line: `4→3, 10→4, 13→6, 16→10, 19→14, 22→18`
- Casing: `10→7, 14→10.5, 16.5→15.5, 19→24, 22→29`

iOS (linear): main `10→8, 13→9, 16→11, 19→22, 22→28`; casing = ×1.5.

### Vanishing route line — the right way

**Do not re-upload GeoJSON.** Upload geometry once with `lineMetrics: true`, then
per update set ONE style property:
- iOS convention: `line-trim-offset = [0.0, fractionTraveled]` on forward
  geometry (`Style++.swift:21-32`).
- Android convention: `line-trim-start = 1.0 − offset` on reversed geometry.
- `fractionTraveled = 1 − remainingDistance / totalDistance`, computed by
  projecting the puck onto the line (iOS slices the previous 10 points).
- Guards (Android `MapboxRouteLineApi.kt:615-659`): throttle **62.5 ms**
  (~16 fps), stop if no progress-index update for **1.5 s**, skip if puck is
  >**10 m** from the line, monotonic after route complete.
- iOS drives this **from the rendered puck position** (`onPuckRender` →
  `travelAlongRouteLine`, `NavigationMapView.swift:374-376`) so the trim never
  desyncs from the visible puck.
- Congestion coloring: `line-gradient` with `["step", ["line-progress"], ...]`
  (soft variant: linear interpolate with 30 m fade gap). Recomputed only when the
  route/congestion changes.

### Layer order (bottom→top, iOS)

alternatives (casing, main) → main traversed → main casing → main line →
**maneuver arrow (stroke, shaft, head casing, head)** → restricted areas → POI.
Everything in slot `"middle"`.

---

## 3. Maneuver arrow (missing entirely in our app)

- Geometry: **30 m before + 30 m after** the maneuver point (Android fixed 30;
  iOS `clamp(50 × metersPerPoint(lat, zoom), 30, 50)`), skipped for `arrive`
  steps (`RouteArrowUtils.kt:34-70`, `ManeuverArrowMapFeatures.swift:54-71`).
- Shaft: LineLayer, round cap/join. Widths (linear z10→z22): shaft 2.9→14.3,
  casing 4.4→22.0.
- Head: SymbolLayer, SDF triangle icon rotated to the bearing of the last
  segment, `iconRotationAlignment: MAP`, allow-overlap. Icon size 0.225→0.885.
- Visibility: hard cutoff below **zoom 14.0** (Android opacity step) / real
  `minZoom 14.5` (iOS).
- Updates: only `icon-rotate` and the source geometry change per step.

---

## 4. Map style + day/night

- Android default: **`mapbox://styles/mapbox/navigation-day-v1`** and
  **`mapbox://styles/mapbox/navigation-night-v1`** (`NavigationStyles.kt:18,:34`).
- iOS v3 default: **`mapbox://styles/mapbox-dash/standard-navigation`** with the
  style-import config `basemap.lightPreset = "day" | "night"` re-applied after
  every style load (`StandardDayStyle.swift:37-41`).
- Auto day/night (iOS `StyleManager.swift`): computes solar sunrise/sunset for
  the current location, switches exactly at the boundary via a one-shot timer;
  default ON (`automaticallyAdjustsStyleForTimeOfDay = true`).
- `preferredFramesPerSecond = 60`, scale bar hidden.

---

## 5. Puck

- Android default nav puck: **2D** `mapbox_navigation_puck_icon2` as
  `bearingImage` (+ blurred shadow, blur 7.5) — no topImage
  (`LocationPuckOptions.kt:211-224`).
- iOS v3 default: **3D GLB** `3DPuck.glb`, scale 1.5, shadows OFF (perf),
  `puckBearing = .course` (`PuckConfigurations.swift:9-17`,
  `NavigationMapView.swift:529-534`).
- Puck animation duration 1000 ms (matches camera; see §1).

---

## 6. Voice guidance

- **Which instruction fires is decided by nav-native** [closed] — the SDKs never
  re-select by distance. Port strategy: fire-once-per-instruction gate keyed on
  the instruction identity (what we implement).
- Overlap policy: **Android queues (FIFO, never interrupts); iOS interrupts and
  replaces**. No urgency model in either.
- **Fallback TTS always speaks plain `announcement`, never SSML**
  (And `VoiceInstructionsTextPlayer.kt:75`; iOS `SystemSpeechSynthesizer.swift:114-124`).
  SSML is only sent to the Mapbox Speech API (Polly audio files).
- Audio session (iOS): `.playback` / mode `.voicePrompt` /
  `[.interruptSpokenAudioAndMixWithOthers, .duckOthers]`; deactivate deferred by
  **1.0 s** so back-to-back prompts don't flap the duck
  (`AVAudioSessionHelper.swift:15-25`).
- Android focus: `AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK`,
  `USAGE_ASSISTANCE_NAVIGATION_GUIDANCE`.
- iOS prefetches audio for the next **3** instructions; mute persisted in
  UserDefaults.
- iOS plays a bundled rerouting sound before the "rerouting" state.

---

## 7. Banner / distance / lanes

### Distance formatting — metric rounding table (Android `MapboxDistanceUtil.kt:80-143`)

| Range | Display | Increment |
|---|---|---|
| < 25 m | meters | round to **5** (floor-clamped to 5 — never "0 m") |
| 25–100 m | meters | round to **25** |
| 100–1000 m | meters | round to **50** |
| 1–3 km | km | **1 decimal** |
| ≥ 3 km | km | 0 decimals |

Android truncates down (99 m → "50 m"); iOS rounds to nearest (99 m → "100 m").
iOS ends the meters band at 999 m. Number bold, unit at 0.75× size.

### "Then" (next-maneuver) banner gate — TIME-based

Show only when `currentStep.durationRemaining ≤ 18 s` **and**
`upcomingStep.expectedTravelTime ≤ 18 s` (`NextBannerView.swift:156-169`).
The tertiary slot is shared: **lane guidance wins over the "then" row**.

### Banner switching

Driven by instruction-index transitions (core events), not re-selected by
distance each tick; only the distance text updates per fix.

### Lanes

Source: `bannerInstructions[].sub.components[]` of type `lane`: `active` (bool),
`directions`, `active_direction`. Highlight the `active_direction` arrow of
active lanes; when `active_direction` missing, fall back to the primary banner's
`modifier`. **Hide the whole lane row unless at least one lane is active.**
Arrow flipped for left-dominant lanes.

---

## 8. Rerouting / routing knobs

- Off-route detection thresholds: **[closed]** — nothing to copy; our own
  detection (50 m, 3 fixes, accuracy-gated) stands.
- **`avoid_maneuver_radius` = 8 s × current speed** (meters) sent on reroute
  requests so the new route can't demand an instant maneuver
  (iOS `RoutingConfig.swift:97`, And `RerouteOptions.kt:82`).
- Route refresh period default: **120 s** (ours: 240 s).
- iOS `detectsReroute` default true; reroute sound played via the voice channel.

---

## 9. Speed limit

Native SDKs read posted speed from nav-native's map-matched horizon **[closed]**,
NOT from route annotations. A Directions-annotation (`maxspeed`) display like
ours is the only option without the closed stack — different data source, same
UI. Sign standard: MUTCD (US/CA) vs Vienna circle (Cyprus ⇒ Vienna).

---

# Addendum — second extraction pass (arrival, callouts, progress, replay)

## 10. Arrival & destination

- Arrival trigger: nav-native `RouteState.COMPLETE` **[closed]**; iOS additionally
  gates on `remainingSteps.count <= 2`, and `routeIsComplete` requires
  `distanceRemaining <= 3 m` (RouteProgress.swift:364-367) — the only open
  numeric arrival threshold.
- Multi-leg: both platforms auto-advance to the next leg on waypoint arrival by
  default (AutoArrivalController returns true / `.automatically`).
- **Destination building highlight** (Android, fully open): on final arrival,
  `queryRenderedFeatures` at the destination pixel on layers
  `building`/`building-extrusion`, clone a FillExtrusionLayer above with
  `fillExtrusionColor #FC2B14`, opacity **0.6**; removed on next-leg start.
  iOS v3 removed this feature entirely.
- Arrival camera (iOS UIKit): stop the nav camera, ease 1.0s to
  pitch 0, zoom+1, centered on destination, padding for the end-of-route card.
- End-of-route card: 200pt (260 with comment), "You have arrived" + destination
  name, 5-star rating → feedback score `(stars-1)*25`.
- Waypoint markers: Android SymbolLayer 14dp circle icons (origin white-center,
  destination grey-center), iconSize interpolate exp 1.5: 0→0.6, 10→0.8,
  12→1.3, 22→2.8. iOS: white CircleLayer (`#FFFFFF`, stroke `#23262D`), radius
  0.75× route width; completed waypoints become transparent.

## 11. Alternative-route ETA callouts

- "Similar ETA" threshold: **3 minutes** on both platforms.
- Android copy: `-%s` / `+%s` / "Similar ETA"; faster text `#09AA74`, slower
  `#EB252A`; diff rounded away from zero to whole minutes; primary route's
  callout hidden during navigation.
- iOS: `<time>` + caption "faster"/"slower"; callout anchored just past the
  deviation (fork) point — window `deviationOffset+0.01 .. +0.05` of route
  length when annotating at the maneuver.
- Alternative duration must be measured **from the start of the primary route**
  (`infoFromStartOfPrimary`), not from the current position, for a fair delta.
- iOS proactive faster-route check: every **120 s**, only when >10 min remain
  and >70 s to next maneuver; accepts a candidate only if it saves **≥10%** of
  remaining time AND shares the same upcoming maneuver.

## 12. Guidance visuals

- **Junction views / signboards**: token-gated premium Mapbox imagery via
  Directions banner `guidance-view` components — not buildable from open data.
  iOS auto-hides the junction panel after 10 s.
- **Road shields**: sprite from
  `api.mapbox.com/styles/v1/{user}/{style}/sprite.json`, ref text drawn
  centered at 0.4× banner font, scaled to 1.2× font size; generic bordered
  badge as fallback, plain text last.
- **Exit badge** (iOS only): bordered pill, "exit-left/right" arrow icon at
  0.4× height, label bold 2/3× font, height 1.2× font.
- **Text abbreviation** (iOS): greedy by ascending `abbr_priority` from banner
  components, re-measuring after each tier, stopping once the text fits.
- **Wayname pill**: current road name from **map-matched** road (not the
  route), capsule pill, shield prepended, hidden when panned/idle or empty.

## 13. Trip progress / ETA formatting

- ETA = now + durationRemaining, recomputed per update; iOS also refreshes on a
  **30 s timer** so wall-clock ETA stays fresh at a standstill.
- Time remaining: hours/minutes never collapse ("1 hr 5 min", never "65 min");
  zero components omitted; < 1 minute renders "< 1 min"; minutes rounded with
  carry.
- iOS colors the time-remaining label by average congestion on the remaining
  leg: low green (0.47,0.77,0.27), moderate orange (0.95,0.65,0.31), heavy red
  (0.91,0.20,0.25), severe dark red.
- Distance remaining rounding increments for the trip bar: metric **2 m**.
- Near arrival (<5 s remaining) iOS hides the distance label.

## 14. Persistent notification (Android reference)

Custom RemoteViews: maneuver icon (flippable for driving side) + distance +
"%s ETA" + primary banner text, single End-Navigation action, channel
importance LOW, id 7654, redraw only when a formatted value changes. Free-drive
variant shows "Free Drive Session".

## 15. Drive simulation (for testing without driving)

Android `ReplayRouteMapper` is a pure function route→timed locations; port
recipe: dedupe points, mark significant vertices (accumulated perpendicular
deviation > 1.5 m), per-vertex target speed from bearing change (quadratic
falloff: max 30 m/s straight, 3 m/s at 90°, 1 m/s U-turn), back-propagate
braking under maxAccel 3 / minAccel −4 m/s², trapezoidal accelerate-cruise-
decelerate per segment, emit at 1 Hz along the polyline, bearings with a
2-point lookahead, playback pump at 100 ms with a speed multiplier. Traffic-
aware variant caps each segment at the Directions `speed` annotation.
iOS `SimulatedLocationManager` alternative: consume the route LineString at
`speed × 1 s` per tick; speed = per-segment expected speed clamped 6–30 m/s.

## 16. Idle timer

iOS disables screen sleep only while the nav view is visible, via a
reference-counted cancellable. (Our wakelock_plus usage is equivalent.)
