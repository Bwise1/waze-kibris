import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:waze_kibris/bootstrap.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Provider.debugCheckInvalidValueType = null;

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  applyMapboxAccessTokenFromDartIfPresent(MapboxOptions.setAccessToken);
  await DI.initializeObjects(WazeEnv.dev);
  await bootstrap(() => const App());
}
