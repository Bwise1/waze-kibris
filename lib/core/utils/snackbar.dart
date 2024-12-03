import 'package:flash/flash_helper.dart';
import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

enum SnackBarType {
  info,
  error,
  success,
}

class SnackBarFactory {
  final String? message;
  final SnackBarType snackbarType;
  final int? duration;

  SnackBarFactory._({required this.snackbarType, this.duration, this.message});

  void show(BuildContext context) {
    if (message == null) {
      return;
    }

    late final Color backgroundColor;

    switch (snackbarType) {
      case SnackBarType.info:
        backgroundColor = styles.theme.textPrimary;
      case SnackBarType.error:
        backgroundColor = styles.theme.red;
      case SnackBarType.success:
        backgroundColor = styles.theme.secondary;
    }
    context.showToast(
      Text(message!, style: styles.typography.t2.textColor(styles.theme.white)),
      backgroundColor: backgroundColor,
      elevation: 0.5,
      alignment: const Alignment(0.0, -0.9),
    );
  }
}

class RSnackBar {
  RSnackBar._();

  static SnackBarFactory info(
    String? message, {
    int? duration,
  }) {
    return SnackBarFactory._(
      message: message,
      snackbarType: SnackBarType.info,
      duration: duration,
    );
  }

  static SnackBarFactory error(
    String? message, {
    int? duration,
  }) {
    return SnackBarFactory._(
      message: message,
      snackbarType: SnackBarType.error,
      duration: duration,
    );
  }

  static SnackBarFactory success(
    String? message, {
    int? duration,
  }) {
    return SnackBarFactory._(
      message: message,
      snackbarType: SnackBarType.success,
      duration: duration,
    );
  }
}
