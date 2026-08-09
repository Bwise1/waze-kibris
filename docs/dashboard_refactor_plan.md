# Dashboard rebuild & code-split refactor plan

Prepared for execution by a separate agent. Every claim below was measured
against the code on branch `nav-smooth-camera`; line numbers are from that
branch and may drift — search for the quoted symbols, not the numbers.

## 0. The problem, measured

- `MainDashboard`'s **entire** widget tree — including the `MapWidget`
  platform view — sits under one `BlocBuilder<NavigationBloc,
  NavigationState>` ([main_dashboard.dart:821](../lib/app/dashboard/view/main_dashboard.dart)).
- `NavigationBloc` emits a new `NavigationInProgress` on **every position
  fix** (~1–5s on a real phone, 1 Hz on the simulator): `copyWith` in
  `_onPositionUpdated` touches `userPosition`, `remainingDistance`,
  `currentSpeed`, etc., so no two states are equal and the whole Stack
  rebuilds each time. The `🔥 MainDashboard build() called` log confirms it.
- 18 `setState` calls in `_MainDashboardState` each also rebuild the whole
  screen.
- `NavigationInProgress.props` includes `congestionNumericData`, a
  `List<double>` of ~350–400 entries. Equatable deep-compares it on every
  emission, `copyWith` copies the reference every fix, and the debug bloc
  observer prints the entire list **twice** per change (current + next
  state). Pure waste on all three counts.
- Side effects run inside `build()`: `updateNavigationViewportPadding(...)`
  is called from the map `LayoutBuilder`'s builder, and `_MeasureHeight`
  registers a post-frame callback on every build.

File sizes (the split targets):

| file | lines |
|---|---|
| `lib/app/dashboard/view/map_controller_mixin.dart` | 2649 |
| `lib/app/dashboard/view/main_dashboard.dart` | 1542 |
| `lib/core/controllers/camera_controller.dart` | 942 |
| `lib/app/dashboard/bloc/navigation_bloc.dart` | 760 |

Why the map itself surviving rebuilds hasn't hurt more: `MapWidget` is a
platform view — Flutter rebuilds its widget shell, not the GL surface. The
cost is everything *around* it: closures, Positioned subtrees, LayoutBuilder
re-runs, padding recomputation, post-frame callback churn, and GC pressure,
every few seconds for a whole trip.

## 1. Target architecture

Three rebuild scopes, strictly separated:

```
DashboardScreen (StatefulWidget, builds ~never)
├── MapLayer                      ← built once; NO bloc dependency
│     └── MapWidget + LayoutBuilder (size changes only)
├── PhaseLayer                    ← rebuilds only on phase transitions
│     (free-drive UI ↔ navigation UI ↔ overview)
└── TelemetryConsumers            ← rebuild per fix, each scoped to
      (banner, speedometer,          exactly the fields it displays
       progress bar, ETA card)
```

**Phase** = which mode the app is in. Changes a handful of times per trip.
**Telemetry** = the per-fix numbers. Changes constantly, consumed by small
leaf widgets only.

No state-management migration. Keep bloc; use `buildWhen` and
`BlocSelector` (both already available via flutter_bloc) plus one
`ValueNotifier` for map size. Do not introduce Riverpod/Provider patterns —
the app already mixes enough approaches.

## 2. Phase A — stop the per-fix rebuild (do this first, land it alone)

### A1. Gate the top-level builder on phase, not state identity

Add to the existing top-level `BlocBuilder<NavigationBloc, NavigationState>`:

```dart
buildWhen: (prev, next) =>
    prev.runtimeType != next.runtimeType ||
    (prev is NavigationInProgress &&
        next is NavigationInProgress &&
        (prev.isOverviewVisible != next.isOverviewVisible ||
         !identical(prev.route, next.route))),
```

`identical` on the route is deliberate: a reroute swaps the object; a
position fix does not. After this single change the full-screen rebuild
happens on start/stop/overview/reroute only. **This is the 80% win and is
one commit on its own.**

### A2. Re-scope the per-fix consumers

Everything under the builder that *does* need per-fix data gets its own
narrow subscription. Wrap each in `BlocSelector` selecting only what it
shows:

- `NavigationOverlay` (instruction banner, ETA, remaining distance/time,
  speedometer, speed limit): give the overlay its own
  `BlocSelector<NavigationBloc, NavigationState, NavTelemetry>` where
  `NavTelemetry` is a small equatable value class (define in
  `navigation_state.dart`): `distanceToNextManeuver, remainingDistance,
  remainingDuration, currentSpeed, speedLimit, currentStepIndex,
  isRerouting`. Selector returns it; equality cuts rebuilds to fixes that
  changed a displayed number.
- `_ReplayControl`, `_TraceShareButton`: only need `state is
  NavigationInProgress` — select the bool.
- The `RouteBar` / progress strip: select `(remainingDistance,
  route.distance)`.

Rule: a leaf may not receive the whole `NavigationInProgress`. If a widget
needs a new field, extend `NavTelemetry`.

### A3. Move side effects out of build

- `updateNavigationViewportPadding` + `_lastMapHeightLogical`: move into a
  `NotificationListener<SizeChangedLayoutNotification>` /
  `LayoutBuilder` that lives in `MapLayer` and only fires the callback when
  height actually changed (>1px), via post-frame. Build stays pure.
- `_MeasureHeight` on the nav card already gates on >1px delta; keep it,
  but it moves with the nav card into the PhaseLayer so it stops
  re-registering when unrelated state changes.

### A4. Slim the hot path in the bloc state

- Remove `congestionNumericData` from `props`. Route-scoped data changes
  only on (re)route — hold it inside the route-scoped part of state and
  compare by `identical`, or wrap in a tiny class whose `==` is identity.
- Debug observer: stop printing whole states. `onChange` for
  `NavigationBloc` should print runtimeType + step index + remaining
  distance, nothing more. (The full-list double print is the reason field
  logs were megabytes.)

### A5. Verification for Phase A (before any file moves)

- Temporarily keep the `🔥 MainDashboard build()` print. Run the simulator
  drive: it must fire on start, overview toggle, reroute, end — **not per
  fix**. The nav trace `camera` events must keep their cadence (proves the
  position→camera pipeline didn't get disconnected: it doesn't go through
  build at all).
- Banner/speedometer/progress must still update every fix (they're now the
  only things that do).
- `flutter analyze` clean; existing tests green
  (`test/nav_*`, they cover padding math, zoom curve, trace recorder).

## 3. Phase B — split the files (mechanical, no behaviour change)

One commit per extraction. Every commit: analyze clean + tests green. No
logic edits in this phase — literal moves with imports fixed. If a move
reveals a bug, note it, don't fix it inline.

### B1. `main_dashboard.dart` (1542) → `lib/app/dashboard/view/`

| new file | contents |
|---|---|
| `dashboard_screen.dart` | `MainDashboard` + state: wiring, lifecycle, bloc listeners only |
| `widgets/map_layer.dart` | MapWidget creation, LayoutBuilder, style/init params |
| `widgets/map_buttons.dart` | `_MapCircleButton`, `_MapCompassButton`, menu/chat/recenter/report cluster |
| `widgets/debug_controls.dart` | `_ReplayControl`, `_TraceShareButton`, `_MeasureHeight` |
| `widgets/arrival_flow.dart` | `_showNavigationCompleteDialog` + arrival sheet wiring |
| (existing) `navigation_overlay.dart` | gains its `BlocSelector` wrapper from A2 |

The WebSocket position push, report fetching, nearby-users fetch currently
living in `_MainDashboardState` move to
`lib/app/dashboard/services/dashboard_side_effects.dart` as a plain class
taking the blocs/services it needs — the screen state just owns and calls
it.

### B2. `map_controller_mixin.dart` (2649) → composed services

The mixin currently owns at least six unrelated jobs. Extract each into a
class under `lib/app/dashboard/services/`, with the mixin holding one
instance and delegating (mixin API stays stable so callers don't churn):

| new file | pulls out |
|---|---|
| `position_pipeline.dart` | stream setup/self-heal/watchdog/backoff, replay merge, `_handlePositionUpdate` orchestration (fusion, snap call, trace `fix` logging) |
| `puck_manager.dart` | puck image loading/updating, `refreshLocationPuck`, mode-based styling |
| `report_layer.dart` | report SymbolLayer, icons, tap hit-testing |
| `saved_places_layer.dart` | saved-pin layer, images, tap resolution, 35m clearance logic |
| `nearby_users_layer.dart` | group member markers |
| `viewport_glue.dart` | `updateNavigationViewportPadding` (already pure math + one call), native viewport enter/exit, `settleCameraOnArrival`, `easeOutOfNavigation` forwarding |

`position_pipeline.dart` is the delicate one — it was field-debugged this
week (stream self-heal, watchdog, stale-at-nav-start). Move it **verbatim**;
the trace event names (`streamStart`, `streamError`, `streamDone`,
`fixGap`, `staleAtNavStart`) are load-bearing for field debugging and must
not change.

### B3. Optional, only if B1/B2 went clean: `navigation_bloc.dart`

Split event handlers into `navigation_bloc/` parts (position update,
reroute, voice) via `part of`. Lowest value of the three; skip if any
earlier step caused churn.

## 4. Explicitly out of scope — do not touch

- `camera_controller.dart` logic (bearing smoothing, zoom curve, padding
  solve): recently tuned against field traces and covered by
  `test/nav_zoom_test.dart` / `test/nav_padding_test.dart`.
- `NavTraceRecorder` and its call sites/event names.
- Snap-to-road, bearing fusion internals.
- Anything in `lib/core/bloc/` (chat/reports/auth) — different feature.
- No package additions, no state-management migration, no lint pass over
  untouched files.

## 5. Acceptance criteria (the definition of done)

1. During simulated navigation, the dashboard's root build runs only on
   phase transitions (verified by counter/log), while banner, speedometer
   and progress update every fix.
2. Nav trace from a simulator run shows `fix`/`snap`/`camera` cadence
   unchanged from before the refactor.
3. `flutter analyze` clean; all `test/nav_*` suites pass unmodified —
   if a test needs edits, the refactor changed behaviour: stop and revisit.
4. No file under `lib/app/dashboard/` exceeds ~700 lines.
5. `git log` reads as a sequence of single-purpose commits, each buildable.

## 6. Suggested commit sequence

1. `buildWhen` phase gate (A1) — the win, isolated.
2. `NavTelemetry` + BlocSelector leaves (A2).
3. Side effects out of build (A3).
4. State slimming + observer quieting (A4).
5–10. One extraction per commit (B1 table rows, then B2 rows).
11. (optional) B3.
