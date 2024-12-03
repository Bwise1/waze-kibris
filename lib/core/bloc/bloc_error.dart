import 'package:equatable/equatable.dart';
import 'package:waze_kibris/common.dart';

class BlocError extends Equatable implements Exception {
  final String message;
  final bool showOnUI, showOnSnackBar;

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

  @override
  List<Object> get props => [message, showOnUI];
}
