import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Debug-only flight recorder for a navigation session.
///
/// Writes one JSON object per line (JSONL) so a drive can be replayed and
/// analysed after the fact — no debugger attached, no scrolling console.
/// Each line is self-contained, so a truncated file is still readable.
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

  /// Seconds since recording began — the x-axis for everything.
  double get _elapsed {
    final start = _startedAt;
    if (start == null) return 0;
    return DateTime.now().difference(start).inMilliseconds / 1000.0;
  }

  /// Begin a new trace. Any previous one is closed first.
  Future<void> start({Map<String, Object?> context = const {}}) async {
    if (!kDebugMode) return;
    await stop();
    try {
      final dir = await getApplicationDocumentsDirectory();
      // Stable name so it's easy to find; each run overwrites the last.
      _file = File('${dir.path}/nav_trace.jsonl');
      _sink = _file!.openWrite(mode: FileMode.write);
      _startedAt = DateTime.now();
      _lines = 0;
      // Header line: everything needed to interpret the rest.
      log('session', {
        'startedAt': _startedAt!.toIso8601String(),
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

  Future<void> stop() async {
    final sink = _sink;
    _sink = null;
    if (sink == null) return;
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
