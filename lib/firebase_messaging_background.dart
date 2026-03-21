import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:waze_kibris/firebase_options.dart';

/// Must be a top-level function. Runs in a background isolate when a
/// notification arrives while the app is terminated (Android / iOS).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}
