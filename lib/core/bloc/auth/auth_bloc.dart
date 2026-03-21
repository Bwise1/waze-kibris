import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/bloc/auth/auth_event.dart';
import 'package:waze_kibris/core/bloc/auth/auth_state.dart';
import 'package:waze_kibris/core/repositories/auth_repository.dart';
import 'package:waze_kibris/core/res/store_keys.dart';
import 'package:waze_kibris/core/services/push_notification_service.dart';
import 'package:waze_kibris/core/utils/user_coordinates.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required AuthRepository authRepository,
    ILocalStorage? localStorage,
  })  : _authRepository = authRepository,
        _localStorage = localStorage ?? getIt<ILocalStorage>(),
        super(const AuthInitial()) {
    on<LoginRequested>(_onLoginRequested);
    on<RegisterRequested>(_onRegisterRequested);
    on<VerifyOtpRequested>(_onVerifyOtpRequested);
    on<ResendOtpRequested>(_onResendOtpRequested);
    on<GoogleAuthRequested>(_onGoogleAuthRequested);
    on<GetProfileRequested>(_onGetProfileRequested);
    on<UpdateProfileRequested>(_onUpdateProfileRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<GetUserCoordinateRequested>(_onGetUserCoordinate);
    on<RefreshTokenRequested>(_onRefreshTokenRequested);
  }
  final ILocalStorage _localStorage;

  final AuthRepository _authRepository;

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const AuthLoading());
      final response = await _authRepository.login(event.email);
      if (response.statusCode == 404) {
        emit(const AuthError(message: 'User not found'));
        return;
      }
      if (response.statusCode == 403) {
        emit(const AuthError(message: 'Invalid email address provided'));
        return;
      }
      emit(
        OtpSent(
          message: response.message,
          userId: response.data?.id ?? '',
          email: response.data?.email ?? '',
        ),
      );
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onRegisterRequested(
    RegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const AuthLoading());
      final response = await _authRepository.register(event.email);
      if (response.statusCode == 409) {
        emit(const AuthError(message: 'Email already exists'));
        return;
      }
      emit(
        AuthRegisterSuccess(
          message: response.message,
        ),
      );
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onVerifyOtpRequested(
    VerifyOtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const AuthLoading());
      final response = await _authRepository.verifyOtp(
        event.email,
        event.code,
        event.type,
      );
      await _localStorage.save(StoreKeys.wazeToken, response.data?.token ?? '');
      await _localStorage.save(
        StoreKeys.wazeRefreshToken,
        response.data?.refreshToken ?? '',
      );

      emit(
        AuthSuccess(
          message: response.message,
          user: response.data?.user,
          token: response.data?.token,
        ),
      );

      await getIt<PushNotificationService>().syncTokenIfLoggedIn();
      add(AuthEvent.getProfileRequested());
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onResendOtpRequested(
    ResendOtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const AuthLoading());
      final response = await _authRepository.resendOtp(event.email);
      if (response.statusCode == 404) {
        emit(const AuthError(message: 'User not found'));
        return;
      }
      emit(
        OtpSent(
          message: response.message,
          userId: response.data?.id ?? '',
          email: response.data?.email ?? '',
        ),
      );
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onGoogleAuthRequested(
    GoogleAuthRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const AuthLoading());
      final response = await _authRepository.firebaseAuth(event.token);
      await _localStorage.save(StoreKeys.wazeToken, response.data?.token ?? '');
      await _localStorage.save(
        StoreKeys.wazeRefreshToken,
        response.data?.refreshToken ?? '',
      );

      emit(
        AuthSuccess(
          message: response.message,
          user: response.data?.user,
          token: response.data?.token,
        ),
      );

      await getIt<PushNotificationService>().syncTokenIfLoggedIn();
      add(AuthEvent.getProfileRequested());
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onGetProfileRequested(
    GetProfileRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      if (isEmptyOrNull(
        _localStorage.get<String>(StoreKeys.wazeToken),
      )) {
        // don't call the get profile function if theres no token in the local
        // store
        return;
      }

      emit(const AuthLoading());
      final response = await _authRepository.getProfile();
      emit(
        AuthSuccess(
          message: response.message,
          user: response.data?.user,
          token: response.data?.token,
        ),
      );
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onUpdateProfileRequested(
    UpdateProfileRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _authRepository.updateProfile(
        firstname: event.firstname,
        lastname: event.lastname,
        profileIcon: event.profileIcon,
      );
      add(const GetProfileRequested());
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await getIt<PushNotificationService>().unregisterAllOnLogout();
    await _localStorage.delete(StoreKeys.wazeToken);
    await _localStorage.delete(StoreKeys.wazeRefreshToken);
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // Non-fatal if Firebase session was already cleared or not used.
    }
    emit(const LoggedOut());
  }

  Future<void> _onGetUserCoordinate(
    GetUserCoordinateRequested event,
    Emitter<AuthState> emit,
  ) async {
    final position = await UserCoordinates.getAndSetUserCoordinate(
      event.context,
    );
    log(position.toString());
//save the user coordinate
    emit(
      UserCoordinate(
        longitude: position?.longitude ?? 0.00,
        latitude: position?.latitude ?? 0.00,
      ),
    );

    if (event.onCallBack != null) {
      event.onCallBack!(
        LatLng(position?.latitude ?? 0.00, position?.longitude ?? 0.00),
      );
    }
  }

  Future<void> _onRefreshTokenRequested(
    RefreshTokenRequested event,
    Emitter<AuthState> emit,
  ) async {
    // NOTE: Token refresh is now handled automatically by AuthInterceptor
    // This method is kept as a manual fallback or explicit refresh trigger
    // It does NOT navigate or show loading states to prevent reload loops

    try {
      if (isEmptyOrNull(
        _localStorage.get<String>(StoreKeys.wazeRefreshToken),
      )) {
        log('❌ No refresh token available');
        // Only navigate if user explicitly triggered this (not from interceptor)
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          context.go(ScreenPaths.signIn);
        }
        return;
      }

      // Silent refresh - no AuthLoading emission, no navigation
      log('🔄 Manual token refresh requested (silent)');

      final response = await _authRepository.getRefreshToken();

      // Save the new tokens
      await _localStorage.save(
        StoreKeys.wazeToken,
        response.data?.token ?? '',
      );
      await _localStorage.save(
        StoreKeys.wazeRefreshToken,
        response.data?.refreshToken ?? '',
      );

      log('✅ Token refreshed successfully (silent)');

      // Only emit success state, no loading state
      emit(
        AuthRefreshTokenSuccess(
          message: response.message,
          refreshToken: response.data!.refreshToken,
          token: response.data!.token,
        ),
      );

      // Call the callback if provided
      event.onTokenRefresh?.call();
    } catch (e) {
      log('❌ Token refresh failed: $e');

      // Clear tokens on failure
      await _localStorage.delete(StoreKeys.wazeToken);
      await _localStorage.delete(StoreKeys.wazeRefreshToken);

      // Only navigate to sign in on complete failure
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        emit(AuthError(message: e.toString()));
        context.go(ScreenPaths.signIn);
      }
    }
  }
}
