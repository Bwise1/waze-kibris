import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/bloc/auth/auth_event.dart';
import 'package:waze_kibris/core/bloc/auth/auth_state.dart';
import 'package:waze_kibris/core/repositories/auth_repository.dart';
import 'package:waze_kibris/core/res/store_keys.dart';

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
        // don't call the get profile function if theres no token in the local store
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
}
