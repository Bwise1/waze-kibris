import 'package:dio/dio.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/models/auth/auth_response.dart';
import 'package:waze_kibris/core/res/store_keys.dart';

abstract class AuthRepository {
  Future<AuthResponse> login(String email);
  Future<AuthResponse> register(String email);
  Future<AuthResponse> verifyOtp(String email, String code, String type);
  Future<AuthResponse> resendOtp(String email);
  Future<AuthResponse> googleAuth(String token);
  Future<AuthResponse> getProfile();
  Future<RefreshTokenResponse> getRefreshToken();
}

class IAuthRepository implements AuthRepository {
  IAuthRepository({Dio? dio, ILocalStorage? store})
      : _dio = dio ?? getIt<Dio>(),
        _store = store ?? getIt<ILocalStorage>();

  final Dio _dio;
  final ILocalStorage _store;

  @override
  Future<AuthResponse> login(String email) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
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
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {'email': email},
      );

      safePrint('${response.data}::: Heloo');

      return AuthResponse.fromJson(response.data!);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<AuthResponse> verifyOtp(String email, String code, String type) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
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
      final response = await _dio.post<Map<String, dynamic>>(
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
      final response = await _dio.post<Map<String, dynamic>>(
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
      final response = await _dio.get<Map<String, dynamic>>(
        '/user/profile',
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
  Future<RefreshTokenResponse> getRefreshToken() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {
          'refresh_token': _store.get<String>(StoreKeys.wazeRefreshToken),
        },
      );
      return RefreshTokenResponse.fromJson(response.data!);
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
