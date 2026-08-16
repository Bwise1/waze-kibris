import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

class WsMessage {
  WsMessage({
    required this.type,
    required this.userId,
    this.content,
    this.groupId,
    this.username,
    this.typing,
  });

  final String type;
  final String userId;
  final String? content;
  final String? groupId;

  /// Sender's display name — sent on typing events, stamped server-side.
  final String? username;

  /// Typing events only: whether they started or stopped.
  final bool? typing;

  factory WsMessage.fromJson(Map<String, dynamic> json) => WsMessage(
        type: json['type']?.toString() ?? 'unknown',
        userId: json['user_id']?.toString() ?? '',
        content: json['content']?.toString(),
        groupId: json['group_id']?.toString(),
        username: json['username']?.toString(),
        typing: json['typing'] as bool?,
      );
}

/// Observable connection lifecycle so UI can show an honest status instead of
/// guessing.
enum WsStatus { disconnected, connecting, connected, reconnecting }

class WebSocketService {
  WebSocketService(this._endpoint, {String? Function()? tokenProvider})
      : _tokenProvider = tokenProvider;

  final String _endpoint;

  /// Returns the current access token, or null when signed out. The token is
  /// sent on the upgrade request; the server derives our identity from it (it
  /// ignores any client-sent user_id).
  final String? Function()? _tokenProvider;

  WebSocketChannel? _channel;
  final _controller = StreamController<WsMessage>.broadcast();

  Stream<WsMessage> get messages => _controller.stream;

  /// Live connection state — listen with a ValueListenableBuilder for
  /// "Connected / Reconnecting…" indicators.
  final ValueNotifier<WsStatus> status = ValueNotifier(WsStatus.disconnected);

  String? _lastUserId;
  double? _lastLatitude;
  double? _lastLongitude;
  double? _lastSubscribeRadiusM;
  bool _intentionalDisconnect = false;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectDelaySeconds = 30;
  static const int _initialReconnectDelaySeconds = 2;

  /// After this many consecutive failures, back off to [_idleRetryDelaySeconds]
  /// instead of hammering every 30s forever. The classic cause is an expired
  /// token: the stored token only rotates when some HTTP call trips the
  /// auth interceptor, so tight WS retries can't fix it — they just burn
  /// battery. The slow cadence keeps self-healing (the next successful HTTP
  /// refresh makes a retry succeed) without the radio cost.
  static const int _fastRetryAttempts = 6;
  static const int _idleRetryDelaySeconds = 300;

  /// Send heartbeat every 25s so proxies/load balancers don't close the connection as idle.
  static const int _heartbeatIntervalSeconds = 25;

  Future<void> connect({
    required String userId,
    required double latitude,
    required double longitude,
    double? subscribeRadiusM,
  }) async {
    _intentionalDisconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    if (_channel != null) return;

    _lastUserId = userId;
    _lastLatitude = latitude;
    _lastLongitude = longitude;
    if (subscribeRadiusM != null) _lastSubscribeRadiusM = subscribeRadiusM;

    await _doConnect(
      userId: userId,
      latitude: latitude,
      longitude: longitude,
      subscribeRadiusM: _lastSubscribeRadiusM,
    );
  }

  Future<void> _doConnect({
    required String userId,
    required double latitude,
    required double longitude,
    double? subscribeRadiusM,
  }) async {
    debugPrint(
        '🔌 WebSocket connecting... url: $_endpoint (attempt ${_reconnectAttempts + 1})');
    status.value =
        _reconnectAttempts > 0 ? WsStatus.reconnecting : WsStatus.connecting;
    try {
      final token = _tokenProvider?.call();
      _channel = IOWebSocketChannel.connect(
        Uri.parse(_endpoint),
        headers: token != null && token.isNotEmpty
            ? {'Authorization': 'Bearer $token'}
            : null,
      );
      // Wait for the upgrade handshake so a refused/unauthorized connection
      // surfaces here instead of pretending to be connected.
      await _channel!.ready;
      _reconnectAttempts = 0;
      status.value = WsStatus.connected;
      debugPrint('🔌 WebSocket connected. url: $_endpoint userId: $userId');
    } catch (e) {
      debugPrint('🔌 WebSocket connect failed: $e');
      _channel = null;
      _scheduleReconnect();
      return;
    }

    _channel!.stream.listen(
      (data) {
        try {
          final jsonMap = jsonDecode(data as String) as Map<String, dynamic>;
          _controller.add(WsMessage.fromJson(jsonMap));
        } catch (_) {
          // ignore malformed messages
        }
      },
      onError: (Object err) {
        debugPrint('🔌 WebSocket error: $err');
        _stopHeartbeat();
        _channel = null;
        _scheduleReconnect();
      },
      onDone: () {
        debugPrint('🔌 WebSocket disconnected');
        _stopHeartbeat();
        _channel = null;
        if (!_intentionalDisconnect) {
          _scheduleReconnect();
        } else {
          status.value = WsStatus.disconnected;
        }
      },
      cancelOnError: false,
    );

    send({
      'type': 'subscribe',
      'user_id': userId,
      'latitude': latitude,
      'longitude': longitude,
      if (subscribeRadiusM != null) 'subscribe_radius_m': subscribeRadiusM,
    });
    debugPrint(
        '🔌 WebSocket sent subscribe (lat: $latitude, lng: $longitude, radiusM: $subscribeRadiusM)');
    _startHeartbeat();
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: _heartbeatIntervalSeconds),
      (_) {
        if (_channel == null) return;
        send({'type': 'ping'});
      },
    );
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _scheduleReconnect() {
    if (_lastUserId == null || _lastLatitude == null || _lastLongitude == null) {
      status.value = WsStatus.disconnected;
      return;
    }
    if (_reconnectTimer != null || _channel != null) return;

    status.value = WsStatus.reconnecting;
    _reconnectAttempts++;
    final delaySeconds = _reconnectAttempts > _fastRetryAttempts
        ? _idleRetryDelaySeconds
        : (_initialReconnectDelaySeconds *
                (1 << _reconnectAttempts.clamp(0, 4)))
            .clamp(_initialReconnectDelaySeconds, _maxReconnectDelaySeconds);
    debugPrint(
        '🔌 WebSocket reconnecting in ${delaySeconds}s (attempt $_reconnectAttempts)');

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      _reconnectTimer = null;
      if (_intentionalDisconnect || _channel != null) return;
      if (_lastUserId == null || _lastLatitude == null || _lastLongitude == null) {
        return;
      }
      await _doConnect(
        userId: _lastUserId!,
        latitude: _lastLatitude!,
        longitude: _lastLongitude!,
        subscribeRadiusM: _lastSubscribeRadiusM,
      );
    });
  }

  /// Push a position/radius update. Values are remembered so a reconnect
  /// re-subscribes with the latest state even if this frame is sent while
  /// offline. Group subscriptions are handled entirely server-side (all of
  /// the user's groups), so there is nothing group-related to send here.
  void updateSubscription({
    required String userId,
    required double latitude,
    required double longitude,
    double? subscribeRadiusM,
  }) {
    _lastUserId = userId;
    _lastLatitude = latitude;
    _lastLongitude = longitude;
    if (subscribeRadiusM != null) _lastSubscribeRadiusM = subscribeRadiusM;

    // Position pushes only happen while the app is live and authed — if the
    // socket is down, that's the signal to try again promptly rather than
    // waiting out the idle backoff.
    if (_channel == null && !_intentionalDisconnect) {
      _reconnectAttempts = 0;
      if (_reconnectTimer == null) _scheduleReconnect();
      return;
    }

    send({
      'type': 'subscribe',
      'user_id': userId,
      'latitude': latitude,
      'longitude': longitude,
      if (subscribeRadiusM != null) 'subscribe_radius_m': subscribeRadiusM,
    });
  }

  void send(Map<String, dynamic> data) {
    final ch = _channel;
    if (ch == null) return;
    ch.sink.add(jsonEncode(data));
  }

  Future<void> disconnect() async {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stopHeartbeat();
    await _channel?.sink.close();
    _channel = null;
    status.value = WsStatus.disconnected;
  }

  void dispose() {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stopHeartbeat();
    _controller.close();
    _channel?.sink.close();
    status.dispose();
  }
}
