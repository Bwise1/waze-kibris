import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Debug/profile-only flight recorder for navigation sessions.
///
/// Writes one JSON object per line (JSONL) so a drive can be replayed and
/// analysed after the fact — no debugger attached, no scrolling console.
/// Each line is self-contained, so a truncated file is still readable.
///
/// Every trip gets its **own timestamped file** under `nav_traces/`, and
/// nothing is overwritten — the point is to go out, drive several test
/// routes, and bring the whole batch back for analysis in one export.
///
/// The point is to capture the *inputs and outputs of the camera together*:
/// what the GPS said, what snap-to-road made of it, what bearing the compass
/// reported, and what the camera actually did in response. Irregularities
/// (map not rotating, puck drifting, zoom hunting) are almost always a
/// mismatch between those, and that's invisible unless they're side by side
/// on the same timeline.
class NavTraceRecorder {
  NavTraceRecorder._();
  static final NavTraceRecorder instance = NavTraceRecorder._();

  IOSink? _sink;
  File? _file;
  DateTime? _startedAt;
  int _lines = 0;

  /// Cap so a long drive can't fill the device. ~200k lines is many hours at
  /// 1 Hz with several events per fix.
  static const int _maxLines = 200000;

  bool get isRecording => _sink != null;
  String? get filePath => _file?.path;
  int get lineCount => _lines;

  /// True in debug *and* profile builds, false in release — unless the
  /// build explicitly opts in with --dart-define=FORCE_NAV_TRACE=true.
  ///
  /// VS Code's "Run Without Debugging" builds profile mode, where
  /// [kDebugMode] is false — gating on that alone would silently record
  /// nothing exactly when you most want a trace (a real drive, phone
  /// unplugged, no debugger slowing the app down).
  ///
  /// The FORCE flag exists for field-tester builds: a release APK is the
  /// right thing to hand an external tester (small, full performance), but
  /// plain release strips tracing — someone building with
  /// `--release` would get an app that tests fine and reports nothing.
  /// The flag must be set at build time, so store builds (built without
  /// it) can never record.
  static const bool _forced = bool.fromEnvironment('FORCE_NAV_TRACE');
  static bool get isAvailable => !kReleaseMode || _forced;

  /// Seconds since recording began — the x-axis for everything.
  double get _elapsed {
    final start = _startedAt;
    if (start == null) return 0;
    return DateTime.now().difference(start).inMilliseconds / 1000.0;
  }

  Future<Directory> _tracesDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/nav_traces');
    await dir.create(recursive: true);
    return dir;
  }

  /// All saved trip traces, oldest first. Includes the file currently being
  /// written, if a trip is in progress.
  Future<List<File>> listTraces() async {
    if (!isAvailable) return const [];
    try {
      final dir = await _tracesDir();
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.jsonl'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      return files;
    } catch (_) {
      return const [];
    }
  }

  /// Delete saved traces that have been uploaded. Refuses while a trip is
  /// recording so the active file can't be yanked out from under the sink.
  ///
  /// Only `*.uploaded.jsonl` files are deleted. A trace that never made it
  /// to the server is the ONLY copy of that drive — a field tester's
  /// accidental long-press permanently destroyed one before this guard
  /// existed. Un-uploaded files stay until the upload sweep ships them,
  /// after which they become deletable.
  Future<int> deleteAll() async {
    if (isRecording) return 0;
    final files = await listTraces();
    var deleted = 0;
    for (final f in files) {
      if (!f.path.endsWith('.uploaded.jsonl')) continue;
      try {
        await f.delete();
        deleted++;
      } catch (_) {}
    }
    return deleted;
  }

  /// Flush buffered lines to disk without ending the recording. Lets the
  /// share flow export a valid snapshot mid-trip.
  Future<void> flushNow() async {
    try {
      await _sink?.flush();
    } catch (_) {}
  }

  /// Begin a new trace file for this trip. Any previous one is closed first.
  Future<void> start({Map<String, Object?> context = const {}}) async {
    if (!isAvailable) return;
    await stop();
    try {
      final dir = await _tracesDir();
      final now = DateTime.now();
      // Sortable per-trip name; seconds make same-minute restarts distinct.
      final stamp = now
          .toIso8601String()
          .substring(0, 19)
          .replaceAll(':', '')
          .replaceAll('-', '')
          .replaceAll('T', '_');
      _file = File('${dir.path}/trip_$stamp.jsonl');
      _sink = _file!.openWrite(mode: FileMode.write);
      _startedAt = now;
      _lines = 0;
      // Header line: everything needed to interpret the rest.
      log('session', {
        'startedAt': now.toIso8601String(),
        'platform': Platform.operatingSystem,
        'osVersion': Platform.operatingSystemVersion,
        ...context,
      });
      debugPrint('📼 Nav trace recording to ${_file!.path}');
    } catch (e) {
      debugPrint('📼 Nav trace failed to start: $e');
      _sink = null;
      _file = null;
    }
  }

  /// Append one event. [type] groups the line; [data] is free-form.
  void log(String type, Map<String, Object?> data) {
    final sink = _sink;
    if (sink == null) return;
    if (_lines >= _maxLines) return;
    try {
      sink.writeln(jsonEncode({
        't': double.parse(_elapsed.toStringAsFixed(3)),
        'type': type,
        ...data,
      }));
      _lines++;
    } catch (_) {
      // Never let logging break navigation.
    }
  }

  /// Close the current trip's file. The file stays on disk for later export.
  Future<void> stop() async {
    final sink = _sink;
    if (sink == null) return;
    // Footer marks a clean end — its absence in a file means the app died
    // or was killed mid-trip, which is itself useful to know.
    log('sessionEnd', {'events': _lines});
    _sink = null;
    try {
      await sink.flush();
      await sink.close();
      debugPrint('📼 Nav trace saved: ${_file?.path} ($_lines lines)');
    } catch (e) {
      debugPrint('📼 Nav trace failed to close: $e');
    }
  }
}

/// Rounds a double for logging — full float precision is noise and triples
/// the file size. Nulls pass through so "no value" stays distinguishable
/// from zero, which matters a lot for bearings.
double? r(double? v, [int places = 5]) =>
    v == null ? null : double.parse(v.toStringAsFixed(places));
