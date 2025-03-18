import 'package:equatable/equatable.dart';
import 'package:waze_kibris/core/models/auth/auth_response.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthRegisterSuccess extends AuthState {
  const AuthRegisterSuccess({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}

class AuthSuccess extends AuthState {
  const AuthSuccess({
    required this.message,
    this.user,
    this.token,
  });

  final String message;
  final User? user;
  final String? token;

  @override
  List<Object?> get props => [message, user, token];
}

class AuthError extends AuthState {
  const AuthError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}

class OtpSent extends AuthState {
  const OtpSent({
    required this.message,
    required this.userId,
    required this.email,
  });

  final String message;
  final String userId;
  final String email;

  @override
  List<Object?> get props => [message, userId, email];
}

class LoggedOut extends AuthState {
  const LoggedOut();
}
