import 'dart:io';

import 'package:flutter/foundation.dart';

/// Mapbox public access token. Read from:
/// 1. Compile-time: --dart-define=MAPBOX_ACCESS_TOKEN=...
/// 2. Runtime: MAPBOX_ACCESS_TOKEN environment variable (e.g. export in shell)
String get mapboxAccessToken {
  const fromDefine = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
  if (fromDefine.isNotEmpty) return fromDefine;
  return Platform.environment['MAPBOX_ACCESS_TOKEN'] ??
      '';
}

/// Calls the given setter only when [mapboxAccessToken] is
/// non-empty (from `--dart-define` or host env during `flutter run`).
///
/// On mobile, Mapbox v11+ can still load tiles using the token in native
/// config (`MBXAccessToken` on iOS, `mapbox_access_token` on Android), so a
/// release build without `--dart-define` is valid when those files are set.
void applyMapboxAccessTokenFromDartIfPresent(
  void Function(String token) setAccessToken,
) {
  final token = mapboxAccessToken;
  if (token.isNotEmpty) {
    setAccessToken(token);
  }
}

enum WazeEnv {
  dev,
  prod;

  const WazeEnv();

  String get apiUrl => switch (this) {
        WazeEnv.dev => kIsWeb || Platform.isIOS
            ? 'https://waze-api.benjys.me'
            : 'https://waze-api.benjys.me',
        WazeEnv.prod => 'https://waze-api.benjys.me',
      };
}
