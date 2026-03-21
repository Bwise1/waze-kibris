import 'package:dio/dio.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/models/auth/auth_response.dart';
import 'package:waze_kibris/core/models/user/nearby_user.dart';
import 'package:waze_kibris/core/res/store_keys.dart';

abstract class AuthRepository {
  Future<AuthResponse> login(String email);
  Future<AuthResponse> register(String email);
  Future<AuthResponse> verifyOtp(String email, String code, String type);
  Future<AuthResponse> resendOtp(String email);
  /// Exchange a Firebase ID token for app JWTs (recommended for Google / Apple via Firebase).
  Future<AuthResponse> firebaseAuth(String idToken);

  /// Legacy: exchange a Google OAuth ID token (not from Firebase) for app JWTs.
  Future<AuthResponse> googleAuth(String idToken);
  Future<AuthResponse> getProfile();
  Future<RefreshTokenResponse> getRefreshToken();
  Future<List<NearbyUser>> getNearbyUsers(double lat, double lon, {double radiusM = 2000});
  Future<void> updateProfile({String? firstname, String? lastname, String? profileIcon});
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
  Future<AuthResponse> firebaseAuth(String idToken) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/firebase/login',
        data: {'id_token': idToken},
      );
      return AuthResponse.fromJson(response.data!);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<AuthResponse> googleAuth(String idToken) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/google/login',
        data: {'id_token': idToken},
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
      final json = response.data!;
      if (json['data'] != null && json['data'] is Map<String, dynamic>) {
        json['data'] = {'user': json['data']};
      }
      return AuthResponse.fromJson(json);
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

  @override
  Future<void> updateProfile({String? firstname, String? lastname, String? profileIcon}) async {
    try {
      final data = <String, dynamic>{};
      if (firstname != null) data['firstname'] = firstname;
      if (lastname != null) data['lastname'] = lastname;
      if (profileIcon != null) data['profile_icon'] = profileIcon;
      await _dio.put<Map<String, dynamic>>(
        '/user/profile',
        data: data,
        options: Options(
          headers: {
            'Authorization':
                'Bearer ${_store.get<String>(StoreKeys.wazeToken)}',
          },
        ),
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<List<NearbyUser>> getNearbyUsers(double lat, double lon, {double radiusM = 2000}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/user/nearby-users',
        queryParameters: {
          'latitude': lat,
          'longitude': lon,
          'radius_m': radiusM.toInt(),
        },
        options: Options(
          headers: {
            'Authorization':
                'Bearer ${_store.get<String>(StoreKeys.wazeToken)}',
          },
        ),
      );
      final data = response.data?['data'];
      if (data is! List<dynamic>) return [];
      return data
          .map((e) => e is Map<String, dynamic> ? NearbyUser.fromJson(e) : null)
          .whereType<NearbyUser>()
          .toList();
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
