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
  });

  factory AuthData.fromJson(Map<String, dynamic> json) =>
      _$AuthDataFromJson(json);

  final String id;
  final String email;
  final User? user;
  final String? token;

  

  Map<String, dynamic> toJson() => _$AuthDataToJson(this);

  @override
  List<Object?> get props => [id, email, user, token];
}

@JsonSerializable()
class User extends Equatable {
  const User({
    required this.id,
    required this.email,
    required this.isVerified,
    required this.preferredLanguage,
    this.authProvider = 'email',
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
  @JsonKey(name: 'created_at') 
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  

  Map<String, dynamic> toJson() => _$UserToJson(this);

  @override
  List<Object?> get props => [
        id,
        email,
        isVerified,
        preferredLanguage,
        authProvider,
        createdAt,
        updatedAt,
      ];
}
