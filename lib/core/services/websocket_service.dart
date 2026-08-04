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
  });

  final String type;
  final String userId;
  final String? content;
  final String? groupId;

  factory WsMessage.fromJson(Map<String, dynamic> json) => WsMessage(
        type: json['type'] as String,
        userId: json['user_id'] as String,
        content: json['content'] as String?,
        groupId: json['group_id'] as String?,
      );
}

class WebSocketService {
  WebSocketService(this._endpoint);

  final String _endpoint;
  WebSocketChannel? _channel;
  final _controller = StreamController<WsMessage>.broadcast();

  Stream<WsMessage> get messages => _controller.stream;

  String? _lastUserId;
  double? _lastLatitude;
  double? _lastLongitude;
  double? _lastSubscribeRadiusM;
  List<String>? _lastActiveGroupIDs;
  bool _intentionalDisconnect = false;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectDelaySeconds = 30;
  static const int _initialReconnectDelaySeconds = 2;
  /// Send heartbeat every 25s so proxies/load balancers don't close the connection as idle.
  static const int _heartbeatIntervalSeconds = 25;

  Future<void> connect({
    required String userId,
    required double latitude,
    required double longitude,
    List<String>? activeGroupIDs,
    double? subscribeRadiusM,
  }) async {
    _intentionalDisconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    if (_channel != null) return;

    _lastUserId = userId;
    _lastLatitude = latitude;
    _lastLongitude = longitude;
    _lastActiveGroupIDs = activeGroupIDs;
    if (subscribeRadiusM != null) _lastSubscribeRadiusM = subscribeRadiusM;

    await _doConnect(
      userId: userId,
      latitude: latitude,
      longitude: longitude,
      activeGroupIDs: activeGroupIDs,
      subscribeRadiusM: _lastSubscribeRadiusM,
    );
  }

  Future<void> _doConnect({
    required String userId,
    required double latitude,
    required double longitude,
    List<String>? activeGroupIDs,
    double? subscribeRadiusM,
  }) async {
    debugPrint('🔌 WebSocket connecting... url: $_endpoint (attempt ${_reconnectAttempts + 1})');
    try {
      _channel = IOWebSocketChannel.connect(Uri.parse(_endpoint));
      _reconnectAttempts = 0;
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
          final type = jsonMap['type']?.toString() ?? 'unknown';
          debugPrint('📩 WebSocket received: type=$type');
          if (type == 'report_update' && jsonMap['content'] != null) {
            try {
              final content = jsonDecode(jsonMap['content'] as String)
                  as Map<String, dynamic>;
              final reportId = content['id'];
              if (reportId != null) {
                debugPrint('📩 WebSocket report_update: reportId=$reportId');
              }
            } catch (_) {}
          }
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
        }
      },
      cancelOnError: false,
    );

    send({
      'type': 'subscribe',
      'user_id': userId,
      'latitude': latitude,
      'longitude': longitude,
      if (activeGroupIDs != null) 'active_group_ids': activeGroupIDs,
      if (subscribeRadiusM != null) 'subscribe_radius_m': subscribeRadiusM,
    });
    debugPrint('🔌 WebSocket sent subscribe (lat: $latitude, lng: $longitude, radiusM: $subscribeRadiusM)');
    _startHeartbeat();
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: _heartbeatIntervalSeconds),
      (_) {
        if (_channel == null) return;
        send({'type': 'ping'});
        debugPrint('🔌 WebSocket heartbeat sent');
      },
    );
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _scheduleReconnect() {
    if (_lastUserId == null || _lastLatitude == null || _lastLongitude == null) return;
    if (_reconnectTimer != null || _channel != null) return;

    _reconnectAttempts++;
    final delaySeconds = (_initialReconnectDelaySeconds * (1 << _reconnectAttempts.clamp(0, 4)))
        .clamp(_initialReconnectDelaySeconds, _maxReconnectDelaySeconds);
    debugPrint('🔌 WebSocket reconnecting in ${delaySeconds}s (attempt $_reconnectAttempts)');

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      _reconnectTimer = null;
      if (_intentionalDisconnect || _channel != null) return;
      if (_lastUserId == null || _lastLatitude == null || _lastLongitude == null) return;
      await _doConnect(
        userId: _lastUserId!,
        latitude: _lastLatitude!,
        longitude: _lastLongitude!,
        activeGroupIDs: _lastActiveGroupIDs,
        subscribeRadiusM: _lastSubscribeRadiusM,
      );
    });
  }

  void updateSubscription({
    required String userId,
    required double latitude,
    required double longitude,
    List<String>? activeGroupIDs,
    double? subscribeRadiusM,
  }) {
    _lastUserId = userId;
    _lastLatitude = latitude;
    _lastLongitude = longitude;
    if (activeGroupIDs != null) _lastActiveGroupIDs = activeGroupIDs;
    if (subscribeRadiusM != null) _lastSubscribeRadiusM = subscribeRadiusM;

    send({
      'type': 'subscribe',
      'user_id': userId,
      'latitude': latitude,
      'longitude': longitude,
      if (activeGroupIDs != null) 'active_group_ids': activeGroupIDs,
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
  }

  void dispose() {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stopHeartbeat();
    _controller.close();
    _channel?.sink.close();
  }
}
