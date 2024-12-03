import 'package:flutter/material.dart';

mixin FormMixin<T extends StatefulWidget> on State<T> {
  final _formKey = GlobalKey<FormState>();
  AutovalidateMode? _autovalidateMode;

  GlobalKey<FormState> get formKey => _formKey;

  AutovalidateMode? get autovalidateMode => _autovalidateMode;

  void validateForm(VoidCallback? callback) {
    final formState = _formKey.currentState;
    if (formState?.validate() ?? false) {
      formState?.save();
      callback?.call();
    } else {
      setState(() {
        _autovalidateMode = AutovalidateMode.onUserInteraction;
      });
    }
  }

  void resetForm() {
    _formKey.currentState?.reset();
  }
}
