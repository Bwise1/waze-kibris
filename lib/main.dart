import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:waze_kibris/bootstrap.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  applyMapboxAccessTokenFromDartIfPresent(MapboxOptions.setAccessToken);

  await DI.initializeObjects(WazeEnv.prod);
  await bootstrap(() => const App());
}
