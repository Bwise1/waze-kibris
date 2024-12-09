import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:waze_kibris/app/app.dart';
import 'package:waze_kibris/bootstrap.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Provider.debugCheckInvalidValueType = null;
  bootstrap(() => const App());
}
