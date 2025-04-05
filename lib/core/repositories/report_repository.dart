import 'package:dio/dio.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/models/auth/auth_response.dart';
import 'package:waze_kibris/core/models/reports/report_response.dart';
import 'package:waze_kibris/core/res/store_keys.dart';

abstract class ReportRepository {
  Future<AuthResponse> getReportById(String reportID);
  Future<GetReportsResponse> getNearByReport(
    String latitude,
    String longitude,
    int radius,
  );
  Future<AuthResponse> getVotesOnReport(String reportID);
  Future<AuthResponse> voteOnReport(
    String voteType,
    String reportID,
  );
  Future<AuthResponse> submitReport(
    String latitude,
    String longitude,
    String type,
  );
}

class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl({Dio? dio, ILocalStorage? store})
      : _dio = dio ?? getIt<Dio>(),
        _store = store ?? getIt<ILocalStorage>();

  final Dio _dio;
  final ILocalStorage _store;
  @override
  Future<GetReportsResponse> getNearByReport(
      String latitude, String longitude, int radius) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/reports/nearby?latitude=$latitude&longitude=$longitude&radius=$radius',
        options: Options(
          headers: {
            'Authorization':
                'Bearer ${_store.get<String>(StoreKeys.wazeToken)}',
          },
        ),
      );
      return GetReportsResponse.fromJson(response.data!);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<AuthResponse> getReportById(String reportID) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/reports/$reportID',
        options: Options(
          headers: {
            'Authorization':
                'Bearer ${_store.get<String>(StoreKeys.wazeToken)}',
          },
        ),
      );
      return AuthResponse.fromJson(response.data!);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<AuthResponse> getVotesOnReport(String id) {
    throw UnimplementedError();
  }

  @override
  Future<AuthResponse> voteOnReport(String voteType, String reportID) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/reports/$reportID/votes',
        options: Options(
          headers: {
            'Authorization':
                'Bearer ${_store.get<String>(StoreKeys.wazeToken)}',
          },
        ),
        data: {'vote_type': voteType},
      );
      return AuthResponse.fromJson(response.data!);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<AuthResponse> submitReport(
    String latitude,
    String longitude,
    String type,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/reports',
        options: Options(
          headers: {
            'Authorization':
                'Bearer ${_store.get<String>(StoreKeys.wazeToken)}',
          },
        ),
        data: {
          'type': type.toUpperCase(),
          'longitude': longitude,
          'latitude': latitude,
        },
      );

      return AuthResponse.fromJson(response.data!);
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
