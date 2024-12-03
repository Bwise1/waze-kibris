import 'package:equatable/equatable.dart';
import 'package:waze_kibris/common.dart';

class BlocError extends Equatable implements Exception {

  const BlocError({
    required this.message,
    this.showOnUI = false,
    this.showOnSnackBar = false,
  });

  factory BlocError.fromFailure(
    Failure failure, {
    bool showOnUI = false,
    bool showOnSnackBar = false,
  }) {
    return BlocError(
      message: failure.message,
      showOnUI: showOnUI,
      showOnSnackBar: showOnSnackBar,
    );
  }
  final String message;
  final bool showOnUI;
  final bool showOnSnackBar;

  @override
  List<Object> get props => [message, showOnUI];
}
