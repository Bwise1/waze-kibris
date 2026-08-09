import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:waze_kibris/app/dashboard/services/nav_trace_recorder.dart';

/// Points path_provider at a real temp dir so the recorder writes to disk.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.dir);
  final String dir;
  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('nav_trace_test');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
  });

  tearDown(() async {
    await NavTraceRecorder.instance.stop();
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  test('writes one parseable JSON object per line, with header and footer',
      () async {
    final rec = NavTraceRecorder.instance;
    await rec.start(context: {'trip': 'test'});
    rec.log('fix', {'lat': 6.45, 'gpsHeading': 142.0});
    rec.log('camera', {'bearingApplied': 138.5, 'zoom': 16.8});
    await rec.stop();

    final traces = await rec.listTraces();
    expect(traces.length, 1);

    final lines = traces.first
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty)
        .toList();

    final decoded =
        lines.map((l) => jsonDecode(l) as Map<String, dynamic>).toList();
    // Every line must carry a timestamp and a type, or correlating events
    // across the drive is impossible.
    for (final m in decoded) {
      expect(m['t'], isA<num>());
      expect(m['type'], isA<String>());
    }
    // The footer marks a clean end; a file without one means the app died
    // mid-trip, which is itself diagnostic.
    expect(decoded.map((m) => m['type']),
        ['session', 'fix', 'camera', 'sessionEnd']);
    expect(decoded[1]['gpsHeading'], 142.0);
  });

  test('each trip gets its own file and the batch accumulates', () async {
    final rec = NavTraceRecorder.instance;
    for (var trip = 0; trip < 3; trip++) {
      await rec.start(context: {'trip': trip});
      rec.log('fix', {'lat': 6.0 + trip});
      await rec.stop();
      // Same-second trips would collide on the timestamped name; a real
      // trip is never shorter than a second.
      await Future<void>.delayed(const Duration(milliseconds: 1100));
    }
    final traces = await rec.listTraces();
    expect(traces.length, 3, reason: 'a day of test drives must all survive');
    // Oldest first, so a batch reads in chronological order.
    final headers = [
      for (final f in traces)
        jsonDecode(f.readAsLinesSync().first) as Map<String, dynamic>
    ];
    expect(headers.map((h) => h['trip']), [0, 1, 2]);
  });

  test('deleteAll clears the batch but refuses during a recording', () async {
    final rec = NavTraceRecorder.instance;
    await rec.start();
    expect(await rec.deleteAll(), 0,
        reason: 'must not delete the file the sink is writing');
    await rec.stop();
    expect(await rec.deleteAll(), 1);
    expect(await rec.listTraces(), isEmpty);
  });

  test('flushNow exports a valid snapshot without ending the recording',
      () async {
    final rec = NavTraceRecorder.instance;
    await rec.start();
    rec.log('fix', {'lat': 1.0});
    await rec.flushNow();
    expect(rec.isRecording, isTrue);
    // The flushed file already parses — this is what mid-trip share sends.
    final lines = File(rec.filePath!).readAsLinesSync();
    expect(lines.length, 2);
    expect(jsonDecode(lines.last)['type'], 'fix');
    await rec.stop();
  });

  test('logging after stop is a no-op rather than a crash', () async {
    final rec = NavTraceRecorder.instance;
    await rec.start();
    await rec.stop();
    // Navigation must never break because recording ended.
    expect(() => rec.log('fix', {'lat': 1.0}), returnsNormally);
  });

  test('r() rounds but keeps null distinct from zero', () {
    // Bearings especially: null means "no reading", 0 means due north.
    expect(r(142.34567, 1), 142.3);
    expect(r(null), isNull);
    expect(r(0.0), 0.0);
  });
}
