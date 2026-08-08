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
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  test('writes one parseable JSON object per line', () async {
    final rec = NavTraceRecorder.instance;
    await rec.start(context: {'trip': 'test'});
    rec.log('fix', {'lat': 6.45, 'gpsHeading': 142.0});
    rec.log('camera', {'bearingApplied': 138.5, 'zoom': 16.8});
    await rec.stop();

    final lines = File('${tmp.path}/nav_trace.jsonl')
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty)
        .toList();

    // session header + the two events
    expect(lines.length, 3);

    final decoded = lines.map((l) => jsonDecode(l) as Map<String, dynamic>);
    // Every line must carry a timestamp and a type, or correlating events
    // across the drive is impossible.
    for (final m in decoded) {
      expect(m['t'], isA<num>());
      expect(m['type'], isA<String>());
    }
    expect(decoded.map((m) => m['type']), ['session', 'fix', 'camera']);
    expect(decoded.elementAt(1)['gpsHeading'], 142.0);
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
