import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/models/reports/report_response.dart';
// Auth header is attached by AuthInterceptor when a token exists.

abstract class ReportRepository {
  Future<SubmitReportResponse> getReportById(String reportID);
  Future<GetReportsResponse> getNearByReport(
    String latitude,
    String longitude,
    int radius,
  );
  Future<GetReportsResponse> getVotesOnReport(int reportID);
  Future<GetSavedLocationsResponse> getSavedLocations();
  Future<GetReportsResponse> voteOnReport(
    String voteType,
    int reportID,
  );
  Future<SubmitReportResponse> submitReport(
    double latitude,
    double longitude,
    String type, {
    XFile? imageFile,
  });
  Future<SaveLocationResponse> saveLocation(
    String locationName,
    String? address,
    double lat,
    double lng,
    String placeId,
  );
}

class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl({Dio? dio, ILocalStorage? store})
      : _dio = dio ?? getIt<Dio>(),
        _store = store ?? getIt<ILocalStorage>();

  final Dio _dio;
  // Kept for backward compatibility with DI signature; auth headers are set via AuthInterceptor.
  // ignore: unused_field
  final ILocalStorage _store;
  @override
  Future<GetReportsResponse> getNearByReport(
    String latitude,
    String longitude,
    int radius,
  ) async {
    try {
      // print(
      //   '/reports/nearby?latitude=$latitude&longitude=$longitude&radius=$radius',
      // );

      final response = await _dio.get<Map<String, dynamic>>(
        '/reports/nearby?latitude=$latitude&longitude=$longitude&radius=$radius',
      );
      // print('hhhh${response.data}');
      return GetReportsResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<SubmitReportResponse> getReportById(String reportID) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/reports/$reportID',
      );
      return SubmitReportResponse.fromJson(response.data!);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<GetSavedLocationsResponse> getSavedLocations() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/saved-locations',
      );
      // debugPrint(response.data.toString());
      log("${response.data.toString()},,,,,,,,,,,,,,,,,,,,,,,,,,,,,,");

      return GetSavedLocationsResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<GetReportsResponse> getVotesOnReport(int id) {
    throw UnimplementedError();
  }

  @override
  Future<GetReportsResponse> voteOnReport(String voteType, int reportID) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/reports/$reportID/votes',
        data: {'vote_type': voteType},
      );
      return GetReportsResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<SaveLocationResponse> saveLocation(
      String locationName, String? address, double lat, double lng, String placeId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/saved-locations',
        data: {
          'name': locationName,
          'address': address,
          'latitude': lat,
          'longitude': lng,
          'place_id': placeId,
        },
      );
      debugPrint(response.data.toString());
      return SaveLocationResponse.fromJson(response.data!);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<SubmitReportResponse> submitReport(
    double latitude,
    double longitude,
    String type, {
    XFile? imageFile,
  }) async {
    try {
      if (imageFile != null) {
        final path = imageFile.path;
        if (path.isNotEmpty) {
          final formData = FormData.fromMap({
            'type': type.toUpperCase(),
            'latitude': latitude,
            'longitude': longitude,
            'image': await MultipartFile.fromFile(
              path,
              filename: imageFile.name,
            ),
          });
          final response = await _dio.post<Map<String, dynamic>>(
            '/reports',
            data: formData,
          );
          return SubmitReportResponse.fromJson(response.data!);
        }
      }
      final response = await _dio.post<Map<String, dynamic>>(
        '/reports',
        data: {
          'type': type.toUpperCase(),
          'longitude': longitude,
          'latitude': latitude,
        },
      );
      return SubmitReportResponse.fromJson(response.data!);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Exception _handleDioError(DioException e) {
    if (e.response != null) {
      final errorData = e.response!.data as Map<String, dynamic>;
      return Exception(errorData['message'] as String? ?? 'An error occurred');
    }
    return Exception('Network error occurred');
  }
}
