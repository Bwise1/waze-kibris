import 'package:flutter/material.dart';

class ModalService {
  static final navigatorKey = GlobalKey<NavigatorState>();

  static Future<T?> showModal<T>(Widget child) {
    return showModalBottomSheet<T>(
      context: navigatorKey.currentContext!,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => child,
    );
  }

  static void closeModal<T>([T? result]) {
    Navigator.of(navigatorKey.currentContext!).pop(result);
  }
}
