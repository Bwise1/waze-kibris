import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:waze_kibris/app/dashboard/services/nav_trace_recorder.dart';

/// Ships finished nav traces to Cloudinary so a remote tester's drives can
/// be analysed without them touching the share sheet at all.
///
/// Upload is via an **unsigned preset** (`nav_trace_upload`, created through
/// the Admin API, locked to the `nav_traces/` folder, raw files only). The
/// app therefore carries no secret — the deliberate trade-off is that anyone
/// with the cloud + preset name could dump files into that folder. Bounded
/// nuisance, and the preset is deletable the moment field testing ends.
///
/// Flow: after every trip ends (and once at app start, to catch trips whose
/// upload failed offline) [uploadPending] sweeps the traces directory.
/// Successfully shipped files are renamed `*.uploaded.jsonl` — still
/// shareable and deletable locally, never uploaded twice.
class NavTraceUploader {
  NavTraceUploader._();
  static final NavTraceUploader instance = NavTraceUploader._();

  // Same account the app's profile pictures already live on.
  static const _cloudName = String.fromEnvironment(
    'TRACE_CLOUD_NAME',
    defaultValue: 'dgqfttdvu',
  );
  static const _uploadPreset = String.fromEnvironment(
    'TRACE_UPLOAD_PRESET',
    defaultValue: 'nav_trace_upload',
  );

  final Dio _dio = Dio();
  bool _sweeping = false;

  /// Short per-install tag so several testers' files don't collide, and so
  /// a batch groups by device when listed. Persisted next to the traces.
  Future<String> _deviceTag() async {
    final traces = await NavTraceRecorder.instance.listTraces();
    final dir = traces.isNotEmpty
        ? traces.first.parent
        : null;
    if (dir == null) return Platform.operatingSystem;
    final f = File('${dir.path}/device_tag.txt');
    if (f.existsSync()) return f.readAsStringSync().trim();
    final rand = Random();
    final tag =
        '${Platform.operatingSystem}_${rand.nextInt(0xFFFF).toRadixString(16).padLeft(4, '0')}';
    f.writeAsStringSync(tag);
    return tag;
  }

  /// Upload every finished, not-yet-uploaded trace. Safe to call often;
  /// re-entry is a no-op while a sweep runs. Never touches the file a
  /// recording is actively writing.
  Future<void> uploadPending() async {
    if (kReleaseMode || _sweeping) return;
    _sweeping = true;
    try {
      final recorder = NavTraceRecorder.instance;
      final files = await recorder.listTraces();
      for (final f in files) {
        if (f.path == recorder.filePath) continue; // still being written
        if (f.path.endsWith('.uploaded.jsonl')) continue;
        await _uploadOne(f);
      }
    } finally {
      _sweeping = false;
    }
  }

  Future<void> _uploadOne(File f) async {
    final name = f.uri.pathSegments.last.replaceAll('.jsonl', '');
    try {
      final tag = await _deviceTag();
      final form = FormData.fromMap({
        'upload_preset': _uploadPreset,
        // Preset already prefixes nav_traces/; this adds device/trip.
        'public_id': '$tag/$name',
        'file': await MultipartFile.fromFile(f.path, filename: '$name.jsonl'),
      });
      final res = await _dio.post<dynamic>(
        'https://api.cloudinary.com/v1_1/$_cloudName/raw/upload',
        data: form,
        options: Options(receiveTimeout: const Duration(seconds: 30)),
      );
      if (res.statusCode == 200) {
        // Keep .jsonl so local share/delete still see it; the marker just
        // takes it out of future sweeps.
        await f.rename(f.path.replaceAll('.jsonl', '.uploaded.jsonl'));
        debugPrint('📤 Trace uploaded: $tag/$name');
      }
    } catch (e) {
      // Offline or Cloudinary down: leave the file; the next sweep (next
      // trip end or next app start) retries. Never let this surface into
      // navigation.
      debugPrint('📤 Trace upload failed for $name: $e');
    }
  }
}
