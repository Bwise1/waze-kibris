import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/services/local_storage.dart';
import 'package:waze_kibris/core/res/store_keys.dart';
import 'package:waze_kibris/core/repositories/auth_repository.dart';

/// Dio interceptor that automatically handles token refresh
/// when receiving 401 Unauthorized responses
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required ILocalStorage localStorage,
    required AuthRepository authRepository,
  })  : _localStorage = localStorage,
        _authRepository = authRepository;

  final ILocalStorage _localStorage;
  final AuthRepository _authRepository;

  // Flag to prevent multiple simultaneous refresh attempts
  bool _isRefreshing = false;

  // Queue to hold failed requests while refreshing
  final List<_RequestOptions> _requestQueue = [];

  /// One retry client for post-refresh replays. requestOptions carry
  /// absolute URLs, so no baseUrl is needed — but timeouts are, or a stalled
  /// replay hangs its caller's Future forever.
  static final Dio _retryDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    // Add auth token to every request
    final token = _localStorage.get<String>(StoreKeys.wazeToken);
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Check if error is 401 Unauthorized or token-expired
    if (err.response?.statusCode == 401 ||
        err.error?.toString().contains('token-expired') == true) {

      log('🔄 Token expired, attempting refresh...');

      // If already refreshing, queue this request
      if (_isRefreshing) {
        log('⏳ Refresh in progress, queuing request...');
        _requestQueue.add(_RequestOptions(
          options: err.requestOptions,
          handler: handler,
        ));
        return;
      }

      _isRefreshing = true;

      try {
        // Attempt to refresh the token
        final refreshToken = _localStorage.get<String>(StoreKeys.wazeRefreshToken);

        if (refreshToken == null || refreshToken.isEmpty) {
          log('❌ No refresh token available, cannot refresh');
          log('🚪 Logging user out and redirecting to sign in...');

          _isRefreshing = false;
          _clearQueue(handler);

          // Clear all tokens since they're invalid
          await _localStorage.delete(StoreKeys.wazeToken);
          await _localStorage.delete(StoreKeys.wazeRefreshToken);

          // Navigate to sign in page and show message
          final context = navigatorKey.currentContext;
          if (context != null && context.mounted) {
            // Show a brief message before navigating
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Session expired. Please sign in again.'),
                duration: Duration(seconds: 3),
                backgroundColor: Colors.orange,
              ),
            );

            // Navigate after a brief delay to show the message
            Future.delayed(const Duration(milliseconds: 500), () {
              if (context.mounted) {
                context.go(ScreenPaths.signIn);
              }
            });
          }

          handler.reject(err);
          return;
        }

        // Call refresh token API
        final response = await _authRepository.getRefreshToken();

        if (response.data?.token != null) {
          // Save new tokens
          await _localStorage.save(
            StoreKeys.wazeToken,
            response.data!.token,
          );
          await _localStorage.save(
            StoreKeys.wazeRefreshToken,
            response.data!.refreshToken,
          );

          log('✅ Token refreshed successfully');

          // Retry the original failed request with new token
          final newToken = response.data!.token;
          err.requestOptions.headers['Authorization'] = 'Bearer $newToken';

          try {
            final retryResponse =
                await _retryDio.fetch<dynamic>(err.requestOptions);

            // Drain the queue BEFORE dropping the refreshing flag: requests
            // 401-ing while we replay must keep queueing rather than start
            // a second refresh against the token we just rotated.
            await _processQueue(newToken);
            _isRefreshing = false;

            handler.resolve(retryResponse);
            return;
          } catch (retryError) {
            log('❌ Retry failed after token refresh: $retryError');
            _isRefreshing = false;
            _clearQueue(handler);
            handler.reject(err);
            return;
          }
        } else {
          log('❌ Token refresh failed: No token in response');
          _isRefreshing = false;
          _clearQueue(handler);
          handler.reject(err);
          return;
        }
      } catch (refreshError) {
        log('❌ Token refresh error: $refreshError');
        log('🚪 Refresh failed, logging user out...');

        _isRefreshing = false;
        _clearQueue(handler);

        // Clear tokens on refresh failure
        await _localStorage.delete(StoreKeys.wazeToken);
        await _localStorage.delete(StoreKeys.wazeRefreshToken);

        // Navigate to sign in page and show message
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          // Show a brief message before navigating
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session expired. Please sign in again.'),
              duration: Duration(seconds: 3),
              backgroundColor: Colors.orange,
            ),
          );

          // Navigate after a brief delay
          Future.delayed(const Duration(milliseconds: 500), () {
            if (context.mounted) {
              context.go(ScreenPaths.signIn);
            }
          });
        }

        handler.reject(err);
        return;
      }
    } else {
      // Not a token error, pass through
      handler.next(err);
    }
  }

  /// Process all queued requests with the new token.
  ///
  /// Snapshot-and-clear FIRST, synchronously: the old version iterated the
  /// live list across awaits and cleared it at the end, so a request queued
  /// mid-replay was wiped without ever being resolved or rejected — its
  /// screen's Future hung forever — and a 401 arriving during the loop
  /// mutated the list being iterated.
  Future<void> _processQueue(String newToken) async {
    final queued = List<_RequestOptions>.of(_requestQueue);
    _requestQueue.clear();
    log('🔄 Processing ${queued.length} queued requests...');

    for (final queuedRequest in queued) {
      queuedRequest.options.headers['Authorization'] = 'Bearer $newToken';

      try {
        final response = await _retryDio.fetch<dynamic>(queuedRequest.options);
        queuedRequest.handler.resolve(response);
      } catch (e) {
        queuedRequest.handler.reject(
          DioException(
            requestOptions: queuedRequest.options,
            error: e,
          ),
        );
      }
    }
  }

  /// Clear all queued requests on failure
  void _clearQueue(ErrorInterceptorHandler handler) {
    log('🗑️ Clearing ${_requestQueue.length} queued requests');

    for (final queuedRequest in _requestQueue) {
      queuedRequest.handler.reject(
        DioException(
          requestOptions: queuedRequest.options,
          error: 'Token refresh failed',
          type: DioExceptionType.cancel,
        ),
      );
    }

    _requestQueue.clear();
  }
}

/// Helper class to hold queued request information
class _RequestOptions {
  _RequestOptions({
    required this.options,
    required this.handler,
  });

  final RequestOptions options;
  final ErrorInterceptorHandler handler;
}
