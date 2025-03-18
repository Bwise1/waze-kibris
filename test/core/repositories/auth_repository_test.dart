import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:waze_kibris/core/models/auth/auth_response.dart';
import 'package:waze_kibris/core/repositories/auth_repository.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late AuthRepository authRepository;
  late MockDio mockDio;

  setUp(() {
    mockDio = MockDio();
    authRepository = IAuthRepository(dio: mockDio);
  });

  group('AuthRepository', () {
    const testEmail = 'test@example.com';
    const testResponse = {
      'message': 'Success',
      'status': 'success',
      'status_code': 200,
      'data': {
        'id': 'test-id',
        'email': 'test@example.com',
      },
    };

    test('login - success', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/auth/login',
          data: {'email': testEmail},
        ),
      ).thenAnswer(
        (_) async => Response(
          data: testResponse,
          requestOptions: RequestOptions(),
        ),
      );

      final result = await authRepository.login(testEmail);

      expect(result, isA<AuthResponse>());
      expect(result.message, equals('Success'));
      expect(result.data?.email, equals(testEmail));
    });

    test('login - failure', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/auth/login',
          data: {'email': testEmail},
        ),
      ).thenThrow(
        DioException(
          response: Response(
            data: {'message': 'Invalid email'},
            requestOptions: RequestOptions(),
          ),
          requestOptions: RequestOptions(),
        ),
      );

      expect(
        () => authRepository.login(testEmail),
        throwsA(isA<Exception>()),
      );
    });

    test('register - success', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/auth/register',
          data: {'email': testEmail},
        ),
      ).thenAnswer(
        (_) async => Response(
          data: testResponse,
          requestOptions: RequestOptions(),
        ),
      );

      final result = await authRepository.register(testEmail);

      expect(result, isA<AuthResponse>());
      expect(result.message, equals('Success'));
      expect(result.data?.email, equals(testEmail));
    });

    test('verifyOtp - success', () async {
      const code = '1234';
      const type = 'login';
      final verifyResponse = {
        ...testResponse,
        'data': {
          'user': {
            'id': 'test-id',
            'email': testEmail,
            'is_verified': true,
            'preferred_language': 'en',
          },
          'token': 'test-token',
        },
      };

      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/auth/verify',
          data: {
            'email': testEmail,
            'code': code,
            'type': type,
          },
        ),
      ).thenAnswer(
        (_) async => Response(
          data: verifyResponse,
          requestOptions: RequestOptions(),
        ),
      );

      final result = await authRepository.verifyOtp(testEmail, code, type);

      expect(result, isA<AuthResponse>());
      expect(result.message, equals('Success'));
      expect(result.data?.user?.email, equals(testEmail));
      expect(result.data?.token, equals('test-token'));
    });

    test('resendOtp - success', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/auth/resend',
          data: {'email': testEmail},
        ),
      ).thenAnswer(
        (_) async => Response(
          data: testResponse,
          requestOptions: RequestOptions(),
        ),
      );

      final result = await authRepository.resendOtp(testEmail);

      expect(result, isA<AuthResponse>());
      expect(result.message, equals('Success'));
      expect(result.data?.email, equals(testEmail));
    });

    test('googleAuth - success', () async {
      const token = 'google-token';
      final googleResponse = {
        ...testResponse,
        'data': {
          'user': {
            'id': 'test-id',
            'email': testEmail,
            'is_verified': true,
            'preferred_language': 'en',
          },
          'token': 'test-token',
        },
      };

      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/auth/google',
          data: {'token': token},
        ),
      ).thenAnswer(
        (_) async => Response(
          data: googleResponse,
          requestOptions: RequestOptions(),
        ),
      );

      final result = await authRepository.googleAuth(token);

      expect(result, isA<AuthResponse>());
      expect(result.message, equals('Success'));
      expect(result.data?.user?.email, equals(testEmail));
      expect(result.data?.token, equals('test-token'));
    });
  });
}
