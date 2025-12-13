import 'dart:io';

import 'package:flutter/foundation.dart';

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
