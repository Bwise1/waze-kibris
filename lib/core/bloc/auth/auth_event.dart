import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  factory AuthEvent.loginRequested({required String email}) {
    return LoginRequested(email: email);
  }

  factory AuthEvent.registerRequested({required String email}) {
    return RegisterRequested(email: email);
  }

  factory AuthEvent.verifyOtpRequested({
    required String email,
    required String code,
    required String type,
  }) {
    return VerifyOtpRequested(email: email, code: code, type: type);
  }

  factory AuthEvent.resendOtpRequested({required String email}) {
    return ResendOtpRequested(email: email);
  }

  factory AuthEvent.googleAuthRequested({required String token}) {
    return GoogleAuthRequested(token: token);
  }

  factory AuthEvent.getProfileRequested() {
    return const GetProfileRequested();
  }

  @override
  List<Object?> get props => [];
}

class LoginRequested extends AuthEvent {
  const LoginRequested({required this.email});

  final String email;

  @override
  List<Object?> get props => [email];
}

class RegisterRequested extends AuthEvent {
  const RegisterRequested({required this.email});

  final String email;

  @override
  List<Object?> get props => [email];
}

class VerifyOtpRequested extends AuthEvent {
  const VerifyOtpRequested({
    required this.email,
    required this.code,
    required this.type,
  });

  final String email;
  final String code;
  final String type;

  @override
  List<Object?> get props => [email, code, type];
}

class ResendOtpRequested extends AuthEvent {
  const ResendOtpRequested({required this.email});

  final String email;

  @override
  List<Object?> get props => [email];
}

class GoogleAuthRequested extends AuthEvent {
  const GoogleAuthRequested({required this.token});

  final String token;

  @override
  List<Object?> get props => [token];
}

class GetProfileRequested extends AuthEvent {
  const GetProfileRequested();
}

class LogoutRequested extends AuthEvent {
  const LogoutRequested();
}
