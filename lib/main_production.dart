import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:waze_kibris/bootstrap.dart';
import 'package:waze_kibris/common.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Provider.debugCheckInvalidValueType = null;
  await DI.initializeObjects(WazeEnv.prod);
  await bootstrap(() => const App());
}
