import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:waze_kibris/common.dart';

enum RequestType {
  get,
  post,
}

const successCodes = [200, 201];

class ThirdPartyHttpClient extends HttpClient {
  ThirdPartyHttpClient({required super.dio});
}

class HttpClient {
  HttpClient({
    required this.dio,
    this.errorResponseMapper,
  }) {
    dio.options.connectTimeout = const Duration(seconds: 60);
    dio.options.receiveTimeout = const Duration(seconds: 60);
  }
  final Dio dio;

  ///allows us map custom error response
  final AppException Function(Response<dynamic>? data)? errorResponseMapper;

  Future<T> get<T>(
    String endpoint, {
    Map<String, dynamic>? query,
    T Function(dynamic)? fromJson,
  }) =>
      _futureNetworkRequest(
        RequestType.get,
        endpoint,
        query: query,
        fromJson: fromJson,
      );

  Future<T> post<T>(
    String endpoint, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? data,
    T Function(dynamic)? fromJson,
  }) =>
      _futureNetworkRequest(
        RequestType.post,
        endpoint,
        query: query,
        data: data,
        fromJson: fromJson,
      );

  Future<T> _futureNetworkRequest<T>(
    RequestType type,
    String endpoint, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? query,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      late Response<dynamic> response;
      switch (type) {
        case RequestType.get:
          response = await dio.get(
            endpoint,
            queryParameters: query,
            data: data,
          );
        case RequestType.post:
          response = await dio.post(
            endpoint,
            queryParameters: query,
            data: data,
          );
      }
      if (successCodes.contains(response.statusCode)) {
        safePrint(response.data);
        if (fromJson != null) {
          return fromJson(response.data['data']);
        }

        if (T == String && response.data is String) {
          return response.data as T;
        } else if (T == int && response.data is int) {
          return response.data as T;
        } else if (T == bool && response.data is bool) {
          return response.data as T;
        } else if (T == double && response.data is double) {
          return response.data as T;
        } else if (response.data is Map<String, dynamic>) {
          return response.data as T;
        } else if (response.data is List<dynamic>) {
          return response.data as T;
        }

        throw UnexpectedServerException();
      }
      throw errorResponseMapper?.call(response) ??
          serverErrorResponseMapper(response);
    } catch (error) {
      safePrint(error);
      if (error is FormatException) {
        throw InvalidArgOrDataException();
      }

      if (error is DioException) {
        if ([
          DioExceptionType.connectionTimeout,
          DioExceptionType.receiveTimeout,
        ].contains(error.type)) {
          throw TimeoutServerException();
        }

        if (error.response?.data != null) {
          throw errorResponseMapper?.call(error.response) ??
              serverErrorResponseMapper(error.response);
        }
      }

      throw UnexpectedServerException();
    }
  }
}

AppException serverErrorResponseMapper(Response<dynamic>? response) {
  if (response == null || response.data == null) {
    return UnexpectedServerException();
  }

  dynamic data;
  try {
    if (response.data is String) {
      data = jsonDecode(response.data as String) as Map<String, dynamic>?;
    } else {
      data = response.data;
    }
  } catch (e) {
    return UnexpectedServerException();
  }

  if (data is Map<String, dynamic>) {
    final message =
        data['message'] is String ? data['message'] as String : null;
    final error = data['error'] is String ? data['error'] as String : null;

    if (message != null) {
      return ServerException(message);
    }
    if (error != null) {
      return ServerException(error);
    }
  }

  return UnexpectedServerException();
}
