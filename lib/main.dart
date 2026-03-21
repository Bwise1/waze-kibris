import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:waze_kibris/bootstrap.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/services/push_notification_service.dart';
import 'package:waze_kibris/firebase_messaging_background.dart';
import 'package:waze_kibris/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  applyMapboxAccessTokenFromDartIfPresent(MapboxOptions.setAccessToken);

  await DI.initializeObjects(WazeEnv.prod);
  await getIt<PushNotificationService>().initialize();
  await getIt<PushNotificationService>().syncTokenIfLoggedIn();
  await bootstrap(() => const App());
}
