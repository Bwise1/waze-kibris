import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:waze_kibris/core/bloc/auth/auth_bloc.dart';
import 'package:waze_kibris/core/bloc/auth/auth_event.dart';
import 'package:waze_kibris/core/bloc/auth/auth_state.dart';
import 'package:waze_kibris/core/models/auth/auth_response.dart';
import 'package:waze_kibris/core/repositories/auth_repository.dart';
import 'package:waze_kibris/core/res/store_keys.dart';

import '../../../fake_local_storage.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late AuthBloc authBloc;
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    authBloc = AuthBloc(
      authRepository: mockAuthRepository,
      localStorage: FakeLocalStorage(),
    );
  });

  tearDown(() {
    authBloc.close();
  });

  group('AuthBloc', () {
    const testEmail = 'test@example.com';
    const testResponse = AuthResponse(
      message: 'Success',
      status: 'success',
      statusCode: 200,
      data: AuthData(
        id: 'test-id',
        email: 'test@example.com',
      ),
    );

    test('initial state is AuthInitial', () {
      expect(authBloc.state, const AuthInitial());
    });

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, OtpSent] when LoginRequested is successful',
      build: () {
        when(() => mockAuthRepository.login(testEmail))
            .thenAnswer((_) async => testResponse);
        return authBloc;
      },
      act: (bloc) => bloc.add(const LoginRequested(email: testEmail)),
      expect: () => [
        const AuthLoading(),
        OtpSent(
          message: testResponse.message,
          userId: testResponse.data!.id,
          email: testResponse.data!.email,
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] when LoginRequested returns 404',
      build: () {
        when(() => mockAuthRepository.login(testEmail)).thenAnswer(
          (_) async => const AuthResponse(
            message: 'User not found',
            status: 'not-found',
            statusCode: 404,
          ),
        );
        return authBloc;
      },
      act: (bloc) => bloc.add(const LoginRequested(email: testEmail)),
      expect: () => [
        const AuthLoading(),
        const AuthError(message: 'User not found'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] when LoginRequested returns 403',
      build: () {
        when(() => mockAuthRepository.login(testEmail)).thenAnswer(
          (_) async => const AuthResponse(
            message: 'Invalid email address provided',
            status: 'not-allowed',
            statusCode: 403,
          ),
        );
        return authBloc;
      },
      act: (bloc) => bloc.add(const LoginRequested(email: testEmail)),
      expect: () => [
        const AuthLoading(),
        const AuthError(message: 'Invalid email address provided'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthRegisterSuccess] when RegisterRequested is successful',
      build: () {
        when(() => mockAuthRepository.register(testEmail)).thenAnswer(
          (_) async => const AuthResponse(
            message: 'User created successfully',
            status: 'created',
            statusCode: 201,
            data: AuthData(
              id: 'test-id',
              email: 'test@example.com',
            ),
          ),
        );
        return authBloc;
      },
      act: (bloc) => bloc.add(const RegisterRequested(email: testEmail)),
      expect: () => [
        const AuthLoading(),
        const AuthRegisterSuccess(message: 'User created successfully'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] when RegisterRequested returns 409',
      build: () {
        when(() => mockAuthRepository.register(testEmail)).thenAnswer(
          (_) async => const AuthResponse(
            message: 'Email already exists',
            status: 'conflict',
            statusCode: 409,
            data: AuthData(),
          ),
        );
        return authBloc;
      },
      act: (bloc) => bloc.add(const RegisterRequested(email: testEmail)),
      expect: () => [
        const AuthLoading(),
        const AuthError(message: 'Email already exists'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthSuccess] when VerifyOtpRequested is successful',
      build: () {
        const verifyResponse = AuthResponse(
          message: 'Verification successful',
          status: 'success',
          statusCode: 200,
          data: AuthData(
            user: User(
              id: 'test-id',
              email: testEmail,
              isVerified: true,
              preferredLanguage: 'en',
            ),
            token: 'test-token',
          ),
        );
        when(() => mockAuthRepository.verifyOtp(testEmail, '1234', 'login'))
            .thenAnswer((_) async => verifyResponse);
        when(() => mockAuthRepository.getProfile()).thenAnswer(
          (_) async => const AuthResponse(
            message: 'User profile retrieved successfully',
            status: 'success',
            statusCode: 200,
            data: AuthData(
              user: User(
                id: 'test-id',
                email: testEmail,
                isVerified: true,
                preferredLanguage: 'en',
              ),
              token: 'test-token',
            ),
          ),
        );
        return authBloc;
      },
      act: (bloc) => bloc.add(
        const VerifyOtpRequested(
          email: testEmail,
          code: '1234',
          type: 'login',
        ),
      ),
      expect: () => [
        const AuthLoading(),
        isA<AuthSuccess>()
            .having((s) => s.message, 'message', 'Verification successful')
            .having((s) => s.user?.email, 'user email', testEmail)
            .having((s) => s.token, 'token', 'test-token'),
        const AuthLoading(),
        isA<AuthSuccess>()
            .having(
              (s) => s.message,
              'message',
              'User profile retrieved successfully',
            )
            .having((s) => s.user?.email, 'user email', testEmail)
            .having((s) => s.token, 'token', 'test-token'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, OtpSent] when ResendOtpRequested is successful',
      build: () {
        when(() => mockAuthRepository.resendOtp(testEmail)).thenAnswer(
          (_) async => const AuthResponse(
            message: 'Verification code sent',
            status: 'success',
            statusCode: 200,
          ),
        );
        return authBloc;
      },
      act: (bloc) => bloc.add(const ResendOtpRequested(email: testEmail)),
      expect: () => [
        const AuthLoading(),
        isA<OtpSent>()
            .having((s) => s.message, 'message', 'Verification code sent'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] when ResendOtpRequested returns 404',
      build: () {
        when(() => mockAuthRepository.resendOtp(testEmail)).thenAnswer(
          (_) async => const AuthResponse(
            message: 'User not found',
            status: 'not-found',
            statusCode: 404,
          ),
        );
        return authBloc;
      },
      act: (bloc) => bloc.add(const ResendOtpRequested(email: testEmail)),
      expect: () => [
        const AuthLoading(),
        const AuthError(message: 'User not found'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthSuccess] when GetProfileRequested is successful',
      build: () {
        final storage = FakeLocalStorage()
          ..seed(StoreKeys.wazeToken, 'existing-access-token');
        when(() => mockAuthRepository.getProfile()).thenAnswer(
          (_) async => AuthResponse(
            message: 'User profile retrieved successfully',
            status: 'success',
            statusCode: 200,
            data: AuthData(
              user: User(
                id: 'test-id',
                email: testEmail,
                isVerified: true,
                preferredLanguage: 'en',
                createdAt: DateTime(2025),
                updatedAt: DateTime(2025),
              ),
            ),
          ),
        );
        return AuthBloc(
          authRepository: mockAuthRepository,
          localStorage: storage,
        );
      },
      act: (bloc) => bloc.add(const GetProfileRequested()),
      expect: () => [
        const AuthLoading(),
        isA<AuthSuccess>()
            .having(
              (s) => s.message,
              'message',
              'User profile retrieved successfully',
            )
            .having((s) => s.user?.email, 'user email', testEmail)
            .having((s) => s.user?.isVerified, 'is verified', true),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [LoggedOut] when LogoutRequested',
      build: () => authBloc,
      act: (bloc) => bloc.add(const LogoutRequested()),
      expect: () => [const LoggedOut()],
    );
  });
}
