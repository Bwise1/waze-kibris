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
        return response.data;
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
          DioExceptionType.receiveTimeout
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
  // final data =
  //     response?.data is String ? jsonDecode(response?.data) : response?.data;
  // if (data is Map) {
  //   if (data['message'] != null) return ServerException(data['message']);
  //   if (data['error'] != null) return ServerException(data['error']);
  // }
  return UnexpectedServerException();
}
