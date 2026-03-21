import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'auth_response.g.dart';

@JsonSerializable()
class AuthResponse extends Equatable {
  const AuthResponse({
    required this.message,
    required this.status,
    required this.statusCode,
    this.data,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseFromJson(json);

  final String message;
  final String status;
  @JsonKey(name: 'status_code')
  final int statusCode;
  final AuthData? data;

  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);

  @override
  List<Object?> get props => [message, status, statusCode, data];
}

@JsonSerializable()
class AuthData extends Equatable {
  const AuthData({
    this.id = '',
    this.email = '',
    this.user,
    this.token,
    this.refreshToken,
  });

  factory AuthData.fromJson(Map<String, dynamic> json) =>
      _$AuthDataFromJson(json);

  final String id;
  final String email;
  final User? user;
  final String? token;
  @JsonKey(name: 'refresh_token')
  final String? refreshToken;

  Map<String, dynamic> toJson() => _$AuthDataToJson(this);

  @override
  List<Object?> get props => [id, email, user, token, refreshToken];
}

@JsonSerializable()
class User extends Equatable {
  const User({
    required this.id,
    required this.email,
    required this.isVerified,
    required this.preferredLanguage,
    this.authProvider = 'email',
    this.username,
    this.firstName,
    this.lastName,
    this.profileIcon,
    this.createdAt,
    this.updatedAt,
  });
  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  final String id;
  final String email;
  @JsonKey(name: 'is_verified')
  final bool isVerified;
  @JsonKey(name: 'preferred_language')
  final String preferredLanguage;
  @JsonKey(name: 'auth_provider')
  final String authProvider;
  final String? username;
  @JsonKey(name: 'firstname')
  final String? firstName;
  @JsonKey(name: 'lastname')
  final String? lastName;
  @JsonKey(name: 'profile_icon')
  final String? profileIcon;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => _$UserToJson(this);

  /// Display name for profile: first+last name, username, or email.
  String get displayName {
    final first = firstName?.trim() ?? '';
    final last = lastName?.trim() ?? '';
    if (first.isNotEmpty || last.isNotEmpty) return '$first $last'.trim();
    if (username != null && username!.trim().isNotEmpty) return username!;
    return email;
  }

  @override
  List<Object?> get props => [
        id,
        email,
        isVerified,
        preferredLanguage,
        authProvider,
        username,
        firstName,
        lastName,
        profileIcon,
        createdAt,
        updatedAt,
      ];
}

@JsonSerializable()
class RefreshToken extends Equatable {
  const RefreshToken({required this.refreshToken, required this.token});

  factory RefreshToken.fromJson(Map<String, dynamic> json) =>
      _$RefreshTokenFromJson(json);
  @JsonKey(name: 'refresh_token')
  final String refreshToken;
  @JsonKey(name: 'access_token')
  final String token;

  Map<String, dynamic> toJson() => _$RefreshTokenToJson(this);

  @override
  List<Object?> get props => [token, refreshToken];
}

@JsonSerializable()
class RefreshTokenResponse extends Equatable {
  const RefreshTokenResponse({
    required this.message,
    required this.status,
    required this.statusCode,
    this.data,
  });

  factory RefreshTokenResponse.fromJson(Map<String, dynamic> json) =>
      _$RefreshTokenResponseFromJson(json);

  final String message;
  final String status;
  @JsonKey(name: 'status_code')
  final int statusCode;
  final RefreshToken? data;
  Map<String, dynamic> toJson() => _$RefreshTokenResponseToJson(this);

  @override
  List<Object?> get props => [message, status, statusCode, data];
}
