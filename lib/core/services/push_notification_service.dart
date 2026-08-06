import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, kDebugMode, kIsWeb, TargetPlatform;
import 'package:permission_handler/permission_handler.dart';
import 'package:waze_kibris/core/res/store_keys.dart';
import 'package:waze_kibris/core/services/local_storage.dart';

/// Firebase Cloud Messaging: permissions, token, backend registration, listeners.
class PushNotificationService {
  PushNotificationService({
    required Dio dio,
    required ILocalStorage storage,
  })  : _dio = dio,
        _storage = storage;

  final Dio _dio;
  final ILocalStorage _storage;

  String get _platformLabel {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return 'android';
  }

  Map<String, String>? get _authHeader {
    final t = _storage.get<String>(StoreKeys.wazeToken);
    if (t == null || t.isEmpty) return null;
    return {'Authorization': 'Bearer $t'};
  }

  Future<void> initialize() async {
    if (kIsWeb) return;

    final messaging = FirebaseMessaging.instance;
    await messaging.setAutoInitEnabled(true);

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      await Permission.notification.request();
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Foreground: optionally show in-app UI or local notification.
      if (kDebugMode) {
        debugPrint(
          'FCM foreground: ${message.notification?.title} ${message.data}',
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Cold start from a tapped notification: the payload arrives before any
    // UI exists, so it is parked until a tap handler is registered.
    //
    // NEVER await this here — main() awaits initialize() before runApp(), and
    // getInitialMessage() can hang indefinitely when APNs is unavailable
    // (notably the iOS Simulator), which strands the app on the splash
    // screen. Fire-and-forget with a timeout instead.
    unawaited(
      FirebaseMessaging.instance
          .getInitialMessage()
          .timeout(const Duration(seconds: 5), onTimeout: () => null)
          .then((initial) {
        if (initial != null) _handleNotificationTap(initial);
      }).catchError((Object e) {
        if (kDebugMode) debugPrint('FCM getInitialMessage skipped: $e');
        return null;
      }),
    );

    FirebaseMessaging.instance.onTokenRefresh.listen((String newToken) {
      syncTokenIfLoggedIn(newToken: newToken);
    });
  }

  // --- Notification tap routing -------------------------------------------

  void Function(String groupId)? _groupChatTapHandler;
  String? _pendingGroupChatId;

  /// Register the navigation handler for "group_chat" notification taps.
  /// If a tap already happened (cold start), it fires immediately.
  void setGroupChatTapHandler(void Function(String groupId)? handler) {
    _groupChatTapHandler = handler;
    final pending = _pendingGroupChatId;
    if (handler != null && pending != null) {
      _pendingGroupChatId = null;
      handler(pending);
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    if (data['type'] != 'group_chat') return;
    final groupId = data['group_id']?.toString();
    if (groupId == null || groupId.isEmpty) return;
    final handler = _groupChatTapHandler;
    if (handler != null) {
      handler(groupId);
    } else {
      _pendingGroupChatId = groupId;
    }
  }

  /// On iOS, FCM `getToken()` requires an APNs device token first or it throws
  /// `apns-token-not-set`. Wait briefly, then fall back without crashing.
  Future<String?> _fcmRegistrationTokenOrNull() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        const attempts = 24;
        const delay = Duration(milliseconds: 250);
        for (var i = 0; i < attempts; i++) {
          final apns = await FirebaseMessaging.instance.getAPNSToken();
          if (apns != null) {
            return await FirebaseMessaging.instance.getToken();
          }
          await Future<void>.delayed(delay);
        }
        if (kDebugMode) {
          debugPrint(
            'FCM: APNs token not ready yet (simulator or pending capability). '
            'Will register on token refresh.',
          );
        }
        return null;
      }
      return await FirebaseMessaging.instance.getToken();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('FCM getToken skipped: $e $st');
      }
      return null;
    }
  }

  /// POST /user/fcm-token when we have a JWT (after login or cold start).
  Future<void> syncTokenIfLoggedIn({String? newToken}) async {
    if (kIsWeb) return;
    try {
      final headers = _authHeader;
      if (headers == null) return;

      final token =
          newToken ?? await _fcmRegistrationTokenOrNull();
      if (token == null || token.isEmpty) return;

      await _dio.post<void>(
        '/user/fcm-token',
        data: {'token': token, 'platform': _platformLabel},
        options: Options(headers: headers),
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('FCM register with API failed: $e $st');
      }
    }
  }

  /// DELETE /user/fcm-token — no body removes all tokens for this user (logout).
  Future<void> unregisterAllOnLogout() async {
    if (kIsWeb) return;
    final headers = _authHeader;
    if (headers == null) return;
    try {
      await _dio.delete<void>(
        '/user/fcm-token',
        options: Options(headers: headers),
      );
    } catch (_) {
      // Best-effort on sign-out.
    }
  }
}
