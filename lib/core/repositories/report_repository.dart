import 'package:dio/dio.dart';
import 'package:waze_kibris/core/models/auth/auth_response.dart';

abstract class ReportRepository {
  Future<AuthResponse> getReportById(String id);
  Future<AuthResponse> getNearByReport(
    String latitude,
    String longitude,
    String radius,
  );
  Future<AuthResponse> getVoteOnReport(String id);
  Future<AuthResponse> submitReport(
    String latitude,
    String longitude,
    String report,
  );
}

class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl({required this.dio});
  final Dio dio;

  @override
  Future<AuthResponse> getNearByReport(
      String latitude, String longitude, String radius) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/reports/nearby?latitude=${latitude}&longitude=${longitude}&radius=${radius}',
      );
      return AuthResponse.fromJson(response.data!);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<AuthResponse> getReportById(String id) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/reports/$id',
      );
      return AuthResponse.fromJson(response.data!);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<AuthResponse> getVoteOnReport(String id) {
    // TODO: implement getVoteOnReport
    throw UnimplementedError();
  }

  @override
  Future<AuthResponse> submitReport(
      String latitude, String longitude, String report) {
    // TODO: implement submitReport
    throw UnimplementedError();
  }

  Exception _handleDioError(DioException e) {
    if (e.response != null) {
      final errorData = e.response!.data as Map<String, dynamic>;
      return Exception(errorData['message'] as String? ?? 'An error occurred');
    }
    return Exception('Network error occurred');
  }
}
