import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import 'package:waze_kibris/common.dart';

abstract class Either<L, R> extends Equatable {
  const Either();

  E fold<E>(E Function(L) ifLeft, E Function(R) ifRight);

  bool get isLeft => fold((_) => true, (_) => false);

  bool get isRight => fold((_) => false, (_) => true);

  L get left => fold(
        (leftValue) => leftValue,
        (_) => throw UnimplementedError("Either:right_can't_be_used"),
      );

  R get right => fold(
        (_) => throw UnimplementedError("Either:left_can't_be_used"),
        (rightValue) => rightValue,
      );

  Future<R> getOrElse(R Function() fallback) async {
    final result = this;
    return result.fold((_) => fallback(), (success) => success);
  }
}

class Left<L, R> extends Either<L, R> {

  const Left(this.value);
  final L value;

  @override
  E fold<E>(E Function(L value) ifLeft, E Function(R value) ifRight) =>
      ifLeft(value);

  @override
  List<Object?> get props => [value];
}

class Right<L, R> extends Either<L, R> {

  const Right(this.value);
  final R value;

  @override
  E fold<E>(E Function(L value) ifLeft, E Function(R value) ifRight) =>
      ifRight(value);

  @override
  List<Object?> get props => [value];
}

extension FutureEitherExtension<L, R> on Future<Either<L, R>> {}

Future<Either<Failure, T>> runAsyncBlock<T>(Future<T> Function() future) async {
  try {
    final result = await future();
    return Right(result);
  }  on AppException catch (e) {
    return Left(Failure(e));
  } on PlatformException catch (e) {
    return Left(Failure.fromStr(e.message ?? 'An unknown error occurred'));
  } catch (e) {
    safePrint(e);
    return Left(Failure.fromStr('An unknown error occurred'));
  }
}

Either<Failure, T> runBlock<T>(T Function() block) {
  try {
    return Right(block());
  } on AppException catch (e) {
    return Left(Failure(e));
  } on PlatformException catch (e) {
    return Left(Failure.fromStr(e.message ?? 'An unknown error occurred'));
  } catch (e) {
    safePrint(e);
    return Left(Failure.fromStr('An unknown error occurred'));
  }
}

class Nothing {
  const Nothing();
}

const nothing = Nothing();
