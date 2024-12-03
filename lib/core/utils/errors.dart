/*
 * Copyright (c) 2024. Orion, Inc.
 *
 */

import 'package:equatable/equatable.dart';

abstract class AppException with EquatableMixin implements Exception {
  String get message;

  @override
  List<Object?> get props => [message];
}

class ServerException extends AppException {

  ServerException(this.msg);
  final String msg;

  @override
  String get message => msg;
}

class TimeoutServerException extends AppException {
  @override
  String get message => 'Connection timeout';
}

class UnexpectedServerException extends AppException {
  @override
  String get message => 'Unexpected error occurred';
}

class InvalidArgOrDataException extends AppException {
  @override
  String get message => 'Invalid argument or data';
}

class UnexpectedException extends AppException {

  UnexpectedException(this.msg);
  final String msg;

  @override
  String get message => msg;
}

class CacheMissException extends AppException {
  @override
  String get message => 'Error retrieving data from cache';
}

class CachePutException extends AppException {
  @override
  String get message => 'Error saving data to cache';
}

class Failure extends Equatable {

  const Failure(this.exception);

  factory Failure.fromStr(String msg) => Failure(UnexpectedException(msg));
  final AppException exception;

  String get message => exception.message;

  @override
  String toString() {
    return '${exception.runtimeType} Failure: $message';
  }

  @override
  List<Object?> get props => [message];
}

class UserNameAlreadyExistException extends AppException {
  @override
  String get message => 'Username already exist';
}

class FailedToGetUserException extends AppException {
  @override
  String get message => 'Failed to get user';
}

class LoginFailedException extends AppException {
  @override
  String get message => 'Ensure required fields are filled';
}

class SignUpFailedException extends AppException {
  @override
  String get message => 'Ensure required fields are filled';
}
