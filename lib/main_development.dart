import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:waze_kibris/bootstrap.dart';
import 'package:waze_kibris/common.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Provider.debugCheckInvalidValueType = null;
  await DI.initializeObjects(WazeEnv.dev);
  await bootstrap(() => const App());
  MapboxOptions.setAccessToken(
      'pk.eyJ1IjoiYm5lanlzNTA0IiwiYSI6ImNtYzAzd2thdzJhbzAyaXMzMDM0cXNqbHgifQ.WWh-NiK8VWaoOilR7HYEvw');
}
