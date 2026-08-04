import 'dart:io';

import 'package:dio/dio.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/models/auth/auth_response.dart';
import 'package:waze_kibris/core/models/user/nearby_user.dart';
import 'package:waze_kibris/core/res/store_keys.dart';

/// Errors surfaced by the username-change flow so the UI can show the right
/// message. Backend maps to HTTP 400/403/409.
class UsernameValidationError implements Exception {
  UsernameValidationError(this.message);
  final String message;
  @override
  String toString() => message;
}

class UsernameAlreadyChangedError implements Exception {
  const UsernameAlreadyChangedError();
  @override
  String toString() =>
      'Your username can only be changed once. Contact support for help.';
}

class UsernameTakenError implements Exception {
  const UsernameTakenError();
  @override
  String toString() => 'That username is already taken.';
}

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

  /// Change the user's username (once-only). Returns the refreshed [User].
  /// Throws [UsernameValidationError] for bad input, [UsernameAlreadyChangedError]
  /// if the user has already used their one change, or [UsernameTakenError]
  /// if the handle is claimed.
  Future<User> changeUsername(String newUsername);

  /// Upload a profile picture file (multipart). Server stores it on
  /// Cloudinary and saves the URL to `profile_icon`. Returns the new URL.
  Future<String> uploadProfilePicture(File image);
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

  @override
  Future<User> changeUsername(String newUsername) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/user/username',
        data: {'username': newUsername},
        options: Options(
          headers: {
            'Authorization':
                'Bearer ${_store.get<String>(StoreKeys.wazeToken)}',
          },
        ),
      );
      final data = response.data?['data'] as Map<String, dynamic>?;
      if (data == null) {
        throw Exception('Missing user in response');
      }
      return User.fromJson(data);
    } on DioException catch (e) {
      // Backend uses status codes 400/403/409 for the three failure modes.
      // Map each to a strongly-typed exception so the UI can react.
      final code = e.response?.statusCode;
      if (code == 403) throw const UsernameAlreadyChangedError();
      if (code == 409) throw const UsernameTakenError();
      if (code == 400) {
        final msg =
            (e.response?.data as Map<String, dynamic>?)?['message'] as String?;
        throw UsernameValidationError(msg ?? 'Invalid username');
      }
      throw _handleDioError(e);
    }
  }

  @override
  Future<String> uploadProfilePicture(File image) async {
    try {
      final size = await image.length();
      print('📸 [UPLOAD-REPO] Step 10: building multipart request '
          '(file=${image.path}, size=${size}B, endpoint=${_dio.options.baseUrl}/user/profile-picture)');
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(image.path),
      });
      final token = _store.get<String>(StoreKeys.wazeToken);
      print('📸 [UPLOAD-REPO] Step 11a: token present=${token != null && token.isNotEmpty}');
      // Explicitly set contentType to multipart. The Dio instance has a
      // default `Content-Type: application/json` header from di.dart that
      // sneaks through when we pass our own Options() — the backend then
      // rejects the mismatched body and returns a bare 404. Forcing the
      // content-type here ensures Dio generates the correct multipart
      // boundary and header regardless of the default.
      final response = await _dio.post<Map<String, dynamic>>(
        '/user/profile-picture',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      print('📸 [UPLOAD-REPO] Step 11b: HTTP ${response.statusCode} '
          'body=${response.data}');
      final data = response.data?['data'] as Map<String, dynamic>?;
      final url = data?['profile_icon'] as String?;
      if (url == null || url.isEmpty) {
        print('📸 [UPLOAD-REPO] ❌ no profile_icon in response.data');
        throw Exception('Upload succeeded but no URL returned');
      }
      return url;
    } on DioException catch (e) {
      print('📸 [UPLOAD-REPO] ❌ DioException status=${e.response?.statusCode} '
          'type=${e.type} message=${e.message}');
      print('📸 [UPLOAD-REPO] ❌ response body=${e.response?.data}');
      throw _handleDioError(e);
    }
  }

  Exception _handleDioError(DioException e) {
    final response = e.response;
    if (response == null) return Exception('Network error occurred');

    // Common HTTP status → friendly messages. These fire when the backend
    // isn't the one answering (nginx 413/502, cloudflare 522, etc.) — the
    // body is HTML, not our JSON envelope, so we can't read `message`.
    switch (response.statusCode) {
      case 413:
        return Exception('File is too large. Please pick a smaller image.');
      case 502:
      case 503:
      case 504:
        return Exception('Server is temporarily unavailable. Try again shortly.');
    }

    // Try to read our JSON error envelope; fall back to a generic string
    // if the body isn't a map (e.g. an nginx HTML error page).
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final msg = data['message'];
      if (msg is String && msg.isNotEmpty) return Exception(msg);
    }
    return Exception('Request failed (HTTP ${response.statusCode})');
  }
}
