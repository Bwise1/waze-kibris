import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/bloc/auth/auth_event.dart';
import 'package:waze_kibris/core/bloc/auth/auth_state.dart';
import 'package:waze_kibris/core/repositories/auth_repository.dart';
import 'package:waze_kibris/core/res/store_keys.dart';
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
      emit(
        AuthSuccess(
          message: response.message,
          user: response.data?.user,
          token: response.data?.token,
        ),
      );

      add(AuthEvent.getProfileRequested());

      await _localStorage.save(StoreKeys.wazeToken, response.data?.token ?? '');
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
      final response = await _authRepository.googleAuth(event.token);
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

  Future<void> _onGetProfileRequested(
    GetProfileRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      if (isEmptyOrNull(
        getIt<ILocalStorage>().get<String>(StoreKeys.wazeToken),
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

  void _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) {
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
  }

  Future<void> _onRefreshTokenRequested(
    RefreshTokenRequested event,
    Emitter<AuthState> emit,
  ) async {
    final context = navigatorKey.currentContext!;

    try {
      if (isEmptyOrNull(
        getIt<ILocalStorage>().get<String>(StoreKeys.wazeRefreshToken),
      )) {
        // just go back to sign in screen if no refresh token
        context.go(ScreenPaths.signIn);
      }

      emit(const AuthLoading());
      context.go(ScreenPaths.loaderPage);

      final response = await _authRepository.getRefreshToken();
      emit(
        AuthRefreshTokenSuccess(
          message: response.message,
          refreshToken: response.data!.refreshToken,
          token: response.data!.token,
        ),
      );

      //save the refresh token and new access token
      await _localStorage.save(
        StoreKeys.wazeToken,
        response.data?.token ?? '',
      );
      await _localStorage.save(
        StoreKeys.wazeRefreshToken,
        response.data?.refreshToken ?? '',
      );

      if (context.mounted) {
        Navigator.pop(context);
      }
      //push screen back to the dashboard after refresh token;
      // this happens due to the in activity of user over a period of days
    } catch (e) {
      emit(AuthError(message: e.toString()));
      if (context.mounted) {
        context.go(ScreenPaths.signIn);
      }
    }
  }
}
