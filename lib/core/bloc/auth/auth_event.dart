import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter/cupertino.dart';
import 'package:latlong2/latlong.dart';

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

  factory AuthEvent.updateProfileRequested({
    String? firstname,
    String? lastname,
    String? profileIcon,
  }) {
    return UpdateProfileRequested(
      firstname: firstname,
      lastname: lastname,
      profileIcon: profileIcon,
    );
  }

  factory AuthEvent.refreshTokenRequested({VoidCallback? onRefreshToken}) {
    return RefreshTokenRequested(onTokenRefresh: onRefreshToken);
  }

  factory AuthEvent.usernameChangeRequested({required String newUsername}) {
    return UsernameChangeRequested(newUsername: newUsername);
  }

  factory AuthEvent.profilePictureUploadRequested({required File image}) {
    return ProfilePictureUploadRequested(image: image);
  }

  factory AuthEvent.getUserCoordinateRequested(
      {required BuildContext context, ValueChanged<LatLng>? onCallBack}) {
    return GetUserCoordinateRequested(context: context, onCallBack: onCallBack);
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

class UpdateProfileRequested extends AuthEvent {
  const UpdateProfileRequested({
    this.firstname,
    this.lastname,
    this.profileIcon,
  });

  final String? firstname;
  final String? lastname;
  final String? profileIcon;

  @override
  List<Object?> get props => [firstname, lastname, profileIcon];
}

class LogoutRequested extends AuthEvent {
  const LogoutRequested();
}

class RefreshTokenRequested extends AuthEvent {
  const RefreshTokenRequested({this.onTokenRefresh});

  final VoidCallback? onTokenRefresh;

  @override
  List<Object?> get props => [onTokenRefresh];
}

class GetUserCoordinateRequested extends AuthEvent {
  const GetUserCoordinateRequested({
    required this.context,
    this.onCallBack,
  });

  final BuildContext context;
  final ValueChanged<LatLng>? onCallBack;
  @override
  List<Object?> get props => [context, onCallBack];
}

class UsernameChangeRequested extends AuthEvent {
  const UsernameChangeRequested({required this.newUsername});
  final String newUsername;
  @override
  List<Object?> get props => [newUsername];
}

class ProfilePictureUploadRequested extends AuthEvent {
  const ProfilePictureUploadRequested({required this.image});
  final File image;
  @override
  List<Object?> get props => [image.path];
}
