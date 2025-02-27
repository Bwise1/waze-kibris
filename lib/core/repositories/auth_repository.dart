import 'package:dio/dio.dart';
import 'package:waze_kibris/core/models/auth/auth_response.dart';

abstract class AuthRepository {
  Future<AuthResponse> login(String email);
  Future<AuthResponse> register(String email);
  Future<AuthResponse> verifyOtp(String email, String code, String type);
  Future<AuthResponse> resendOtp(String email);
  Future<AuthResponse> googleAuth(String token);
  Future<AuthResponse> getProfile();
}

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required this.dio});

  final Dio dio;

  @override
  Future<AuthResponse> login(String email) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email},
      );
      return AuthResponse.fromJson(response.data!);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<AuthResponse> register(String email) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {'email': email},
      );
      return AuthResponse.fromJson(response.data!);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<AuthResponse> verifyOtp(String email, String code, String type) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/auth/verify',
        data: {
          'email': email,
          'code': code,
          'type': type,
        },
      );
      return AuthResponse.fromJson(response.data!);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<AuthResponse> resendOtp(String email) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/auth/resend',
        data: {'email': email},
      );
      return AuthResponse.fromJson(response.data!);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<AuthResponse> googleAuth(String token) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/auth/google',
        data: {'token': token},
      );
      return AuthResponse.fromJson(response.data!);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<AuthResponse> getProfile() async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/user/profile',
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
