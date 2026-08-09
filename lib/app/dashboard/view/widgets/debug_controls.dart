import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:waze_kibris/app/dashboard/services/nav_trace_recorder.dart';
import 'package:waze_kibris/app/dashboard/services/route_replay_service.dart';
import 'package:waze_kibris/app/dashboard/view/widgets/map_buttons.dart';
import 'package:waze_kibris/core/models/directions/mapbox_directions_response.dart';

/// Reports its child's laid-out height. Used to measure the navigation card
/// so the camera can frame the puck above it — hardcoding a height would
/// drift the moment the card's content changes (lane guidance, exit numbers).
class MeasureHeight extends StatefulWidget {
  const MeasureHeight({required this.child, required this.onHeight, super.key});
  final Widget child;
  final ValueChanged<double> onHeight;

  @override
  State<MeasureHeight> createState() => _MeasureHeightState();
}

class _MeasureHeightState extends State<MeasureHeight> {
  final GlobalKey _key = GlobalKey();

  void _report(Duration _) {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    widget.onHeight(box.size.height);
  }

  @override
  Widget build(BuildContext context) {
    // Measure after layout; the callback fires each build so the padding
    // follows the card as its content grows and shrinks.
    WidgetsBinding.instance.addPostFrameCallback(_report);
    return KeyedSubtree(key: _key, child: widget.child);
  }
}

/// Debug-only: flush the nav trace and hand it to the share sheet, so a
/// drive recorded on a real phone can be pulled off and analysed.
class TraceShareButton extends StatefulWidget {
  const TraceShareButton({this.isNavigating = false, super.key});

  /// Whether a trip is in progress — decides if a stopped recorder is a
  /// failure (red 'off') or just the idle state between trips.
  final bool isNavigating;

  @override
  State<TraceShareButton> createState() => _TraceShareButtonState();
}

class _TraceShareButtonState extends State<TraceShareButton> {
  Timer? _tick;
  int _savedTrips = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
    // Refresh the event counter so it's visibly climbing — proof the
    // recorder is alive without needing a console. While recording, the
    // count comes from memory, so skip the directory listing and only pay
    // for a cheap setState; when idle, list the batch on a slow cadence.
    // (The first version listed the directory every 2s forever — needless
    // filesystem churn on a phone that's already running GPS + map.)
    _tick = Timer.periodic(const Duration(seconds: 2), (_) {
      if (NavTraceRecorder.instance.isRecording) {
        if (mounted) setState(() {});
      } else if (_tickCount++ % 5 == 0) {
        _refresh();
      }
    });
  }

  int _tickCount = 0;

  Future<void> _refresh() async {
    final traces = await NavTraceRecorder.instance.listTraces();
    if (mounted) setState(() => _savedTrips = traces.length);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Share every saved trip in one go. Recording keeps running — the
  /// active file is flushed first so it exports as a valid snapshot.
  Future<void> _share(BuildContext context) async {
    final recorder = NavTraceRecorder.instance;
    await recorder.flushNow();
    final traces = await recorder.listTraces();
    if (traces.isEmpty) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [for (final f in traces) XFile(f.path)],
        text: 'Nav traces — ${traces.length} trip(s)',
      ),
    );
  }

  /// Long-press: clear the batch after it's been sent. Refused while a
  /// trip is recording so the active file isn't deleted under the sink.
  Future<void> _deleteAll(BuildContext context) async {
    final deleted = await NavTraceRecorder.instance.deleteAll();
    await _refresh();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(deleted > 0
            ? 'Deleted $deleted trace(s)'
            : 'Nothing deleted (recording in progress?)'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recorder = NavTraceRecorder.instance;
    final recording = recorder.isRecording;
    final navigating = widget.isNavigating;

    // Nothing recorded and nothing recording: stay out of the way.
    if (!recording && !navigating && _savedTrips == 0) {
      return const SizedBox.shrink();
    }

    // Phone-only feedback: with no console on a real drive, a silent
    // failure to record would waste the whole trip. A climbing count means
    // it's writing; red 'off' during navigation means it isn't. Between
    // trips the badge shows how many traces are banked for export.
    final failed = navigating && !recording;
    final label = recording
        ? '${recorder.lineCount}'
        : failed
            ? 'off'
            : '$_savedTrips 🚗';

    return GestureDetector(
      onTap: () => _share(context),
      onLongPress: recording ? null : () => _deleteAll(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: failed ? Colors.red.shade700 : Colors.black87,
          borderRadius: BorderRadius.circular(21),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              failed ? Icons.error_outline : Icons.ios_share,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Debug-only control for the drive simulator: play/stop, and cycle the
/// playback speed. Never present in release builds.
class ReplayControl extends StatefulWidget {
  const ReplayControl({required this.route, super.key});
  final MapboxRoute? route;

  @override
  State<ReplayControl> createState() => _ReplayControlState();
}

class _ReplayControlState extends State<ReplayControl> {
  static const _speeds = [1.0, 2.0, 4.0, 8.0];
  int _speedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final replay = RouteReplayService.instance;
    final running = replay.isRunning;
    return Column(
      children: [
        MapCircleButton(
          icon: running ? Icons.stop_rounded : Icons.play_arrow_rounded,
          backgroundColor: running ? Colors.red : Colors.black87,
          iconColor: Colors.white,
          onTap: () {
            final route = widget.route;
            if (route == null) return;
            setState(() {
              if (running) {
                replay.stop();
              } else {
                replay.start(route, speedMultiplier: _speeds[_speedIndex]);
              }
            });
          },
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            setState(() {
              _speedIndex = (_speedIndex + 1) % _speeds.length;
              replay.setSpeedMultiplier(_speeds[_speedIndex]);
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_speeds[_speedIndex].toStringAsFixed(0)}x',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
