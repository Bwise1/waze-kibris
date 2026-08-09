import 'package:flutter/material.dart';
import 'package:waze_kibris/app/dashboard/bloc/navigation_bloc.dart';
import 'package:waze_kibris/app/dashboard/view/arrival_summary_sheet.dart';

/// Present the arrival sheet and wire up the "end navigation on any dismiss"
/// safety net.
///
/// [onSettleCamera] is called immediately (before the sheet slides up) so the
/// map exits course-up framing while the user is looking at it. [onEnd] runs
/// when the sheet closes — via the Done button *or* swipe/scrim tap — so a
/// swipe doesn't leave the route line, snap service and nav bloc running with
/// no UI to stop them.
Future<void> showArrivalFlow({
  required BuildContext context,
  required NavigationInProgress state,
  required VoidCallback onSettleCamera,
  required VoidCallback onEnd,
  required bool Function() isMounted,
}) async {
  // What Waze and Google do on arrival: stop driving the camera and level
  // the map out. Course-up 3D framing exists to show the road ahead — once
  // you've stopped there is no road ahead, and staying tilted and rotated
  // makes it hard to see where you actually are relative to the building.
  onSettleCamera();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => ArrivalSummarySheet(
      state: state,
      // Only dismiss the sheet here; the teardown runs in .whenComplete so
      // that swiping it away tears down too.
      onDone: () {},
    ),
  );
  // The sheet can also be dismissed by swiping or tapping the scrim, which
  // skips the Done button entirely. Ending navigation here covers every
  // path — otherwise a swipe left the route line, snap service and nav
  // state running with no UI to stop them.
  if (isMounted()) onEnd();
}
