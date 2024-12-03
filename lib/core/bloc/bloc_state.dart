import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:waze_kibris/common.dart';

enum PageStateType {
  initial,
  loading,
  success,
  error,
  submitting,
  paginating,
}

@immutable
abstract class _AbstractBzState extends Equatable {

  const _AbstractBzState({required this.type});
  final PageStateType type;

  bool get isError => type == PageStateType.error;

  bool get isNotError => !isError;

  bool get isLoading => type == PageStateType.loading;

  bool get isNotLoading => !isLoading;

  bool get isSuccess => type == PageStateType.success;

  bool get isSubmitting => type == PageStateType.submitting;

  bool get isNotSubmitting => !isSubmitting;

  bool get isNotSuccess => !isSuccess;

  bool get isInitial => type == PageStateType.initial;

  _AbstractBzState copy();

  @override
  List<Object?> get props => [type];
}

class BlocState extends _AbstractBzState {

  const BlocState({super.type = PageStateType.loading, this.error});
  final BlocError? error;

  @override
  BlocState copy({PageStateType? type, BlocError? error}) {
    return BlocState(type: type ?? this.type, error: error ?? this.error);
  }

  BlocState copyWithLoadingPageStateType() {
    return copy(type: PageStateType.loading);
  }

  BlocState copyWithErrorPageStateType({BlocError? error}) {
    return copy(type: PageStateType.error, error: error);
  }

  BlocState copyWithSuccessPageStateType() {
    return copy(type: PageStateType.success);
  }
}
