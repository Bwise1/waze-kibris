import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/bloc/auth/auth_event.dart';
import 'package:waze_kibris/core/models/auth/auth_response.dart' as models;
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
    on<UsernameChangeRequested>(_onUsernameChangeRequested);
    on<ProfilePictureUploadRequested>(_onProfilePictureUploadRequested);
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

  /// The repositories normalise every no-response failure (dead DNS,
  /// timeout, refused connection) to exactly this message; server-responded
  /// failures (401 etc.) carry other messages. That makes it a reliable
  /// "offline vs actually rejected" classifier.
  static bool _isNetworkError(Object e) =>
      e.toString().contains('Network error occurred');

  Timer? _profileRetryTimer;
  int _profileRetryAttempt = 0;
  static const _profileRetryDelays = [3, 8, 20, 45, 90]; // seconds

  void _scheduleProfileRetry() {
    if (_profileRetryAttempt >= _profileRetryDelays.length) return;
    final delay = _profileRetryDelays[_profileRetryAttempt++];
    _profileRetryTimer?.cancel();
    _profileRetryTimer = Timer(
      Duration(seconds: delay),
      () => add(const GetProfileRequested()),
    );
  }

  @override
  Future<void> close() {
    _profileRetryTimer?.cancel();
    return super.close();
  }

  Future<void> _onGetProfileRequested(
    GetProfileRequested event,
    Emitter<AuthState> emit,
  ) async {
    final token = _localStorage.get<String>(StoreKeys.wazeToken);
    try {
      if (isEmptyOrNull(token)) {
        // don't call the get profile function if theres no token in the local
        // store
        return;
      }

      // Don't knock an already-signed-in UI back to a loading state on a
      // background retry.
      if (state is! AuthSuccess) emit(const AuthLoading());
      final response = await _authRepository.getProfile();
      _profileRetryAttempt = 0;
      final user = response.data?.user;
      if (user != null) {
        await _localStorage.save(
          StoreKeys.cachedUser,
          jsonEncode(user.toJson()),
        );
      }
      emit(
        AuthSuccess(
          message: response.message,
          user: user,
          token: response.data?.token,
        ),
      );
    } catch (e) {
      // A launch with no network used to emit AuthError here, which the UI
      // renders as "Guest" with no logout — for the whole session, even
      // though the token was never even validated (the request never left
      // the phone; field log: 'Failed host lookup: waze-api.benjys.me').
      // Offline with a stored token is NOT logged out: show the cached
      // profile and retry with backoff until the network returns.
      if (_isNetworkError(e)) {
        final cached =
            _localStorage.get<Map<String, dynamic>>(StoreKeys.cachedUser);
        if (cached != null) {
          try {
            emit(
              AuthSuccess(
                message: 'offline',
                user: models.User.fromJson(cached),
                token: token,
              ),
            );
          } catch (_) {
            // Corrupt cache: fall through, retry will refresh it.
          }
        }
        _scheduleProfileRetry();
        return;
      }
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

  Future<void> _onUsernameChangeRequested(
    UsernameChangeRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Snapshot the current AuthSuccess so we can restore it after showing
    // ProfileUpdating (spinner) — otherwise the profile screen loses its
    // user data mid-flight and pops out to nothing.
    final priorAuth =
        state is AuthSuccess ? state as AuthSuccess : null;
    emit(const ProfileUpdating());
    try {
      final updatedUser = await _authRepository.changeUsername(event.newUsername);
      emit(AuthSuccess(
        message: 'Username updated',
        user: updatedUser,
        token: priorAuth?.token,
      ));
    } catch (e) {
      emit(ProfileUpdateFailed(message: e.toString()));
      if (priorAuth != null) emit(priorAuth);
    }
  }

  Future<void> _onProfilePictureUploadRequested(
    ProfilePictureUploadRequested event,
    Emitter<AuthState> emit,
  ) async {
    log('📸 [UPLOAD-BLOC] Step 7: handler entered, path=${event.image.path}');
    final priorAuth =
        state is AuthSuccess ? state as AuthSuccess : null;
    emit(const ProfileUpdating());
    log('📸 [UPLOAD-BLOC] Step 8: emitted ProfileUpdating');
    try {
      log('📸 [UPLOAD-BLOC] Step 9: calling repo.uploadProfilePicture');
      final newUrl = await _authRepository.uploadProfilePicture(event.image);
      log('📸 [UPLOAD-BLOC] Step 12: repo returned URL: $newUrl');
      final updatedUser = priorAuth?.user?.copyWith(profileIcon: newUrl);
      emit(AuthSuccess(
        message: 'Profile picture updated',
        user: updatedUser ?? priorAuth?.user,
        token: priorAuth?.token,
      ));
      log('📸 [UPLOAD-BLOC] Step 13: emitted AuthSuccess with new icon');
    } catch (e, st) {
      log('📸 [UPLOAD-BLOC] ❌ upload threw: $e\n$st');
      emit(ProfileUpdateFailed(message: e.toString()));
      if (priorAuth != null) emit(priorAuth);
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
