/*
 * Copyright (c) Relett 2024. All Rights Reserved.
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:waze_kibris/common.dart';

class CustomTextField extends StatefulWidget {
  const CustomTextField({
    required this.hintText,
    super.key,
    this.controller,
    this.obscureText = false,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.done,
    this.onChanged,
    this.onFieldSubmitted,
    this.validator,
    this.inputFormatters,
    this.suffix,
    this.password = false,
    this.prefix,
    this.shouldHideError = true,
    this.focusNode,
    this.initialValue,
    this.enabled = true,
    this.onTap,
    this.maxLength,
    this.minLength,
  });
  final TextEditingController? controller;
  final String hintText;
  final bool obscureText;
  final int maxLines;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final void Function(String)? onChanged;
  final String? Function(String?)? validator;
  final void Function(String?)? onFieldSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffix;
  final Widget? prefix;

  final bool? password;
  final bool shouldHideError;
  final FocusNode? focusNode;
  final String? initialValue;
  final bool enabled;
  final void Function()? onTap;
  final int? maxLength;
  final int? minLength;

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscureText = false;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      focusNode: widget.focusNode,
      controller: widget.controller,
      onTap: widget.onTap,
      initialValue: widget.initialValue,
      readOnly: widget.onTap != null,
      obscureText: _obscureText,
      decoration: InputDecoration(
        enabled: widget.enabled,
        hintText: widget.hintText,
        hintStyle: styles.typography.t2
            .textColor(styles.theme.nu1)
            .textHeight(0)
            .regular,
        suffixIcon: widget.password ?? false
            ? IconButton(
                onPressed: () => setState(() => _obscureText = !_obscureText),
                icon: AppIcon(
                  _obscureText
                      ? 'Assets.icons.regular.eye'
                      : 'Assets.icons.regular.eyeDisable',
                ),
              )
            : widget.suffix,
        prefixIcon: widget.prefix,
        errorStyle: styles.typography.t2.regular.textColor(styles.theme.red),
      ),
      maxLines: widget.maxLines,
      onFieldSubmitted: widget.onFieldSubmitted,
      style: styles.typography.t2.regular.textColor(styles.theme.textPrimary),
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      inputFormatters: widget.inputFormatters,
      onChanged: widget.onChanged,
      cursorOpacityAnimates: true,
      validator: widget.validator,
      maxLength: widget.maxLength,
      minLines: widget.minLength,
    );
  }
}

class CustomTextFieldWithTitle extends StatefulWidget {
  const CustomTextFieldWithTitle({
    required this.title,
    required this.hintText,
    super.key,
    this.controller,
    this.obscureText = false,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.done,
    this.onChanged,
    this.validator,
    this.onFieldSubmitted,
    this.inputFormatters,
    this.isPassword = false,
    this.info,
    this.suffix,
    this.focusNode,
    this.isRequired = false,
    this.initialValue = '',
    this.enabled = true,
    this.prefix,
    this.showOptionalText = false,
    this.maxLength,
    this.minLength,
  });
  final TextEditingController? controller;
  final String title;
  final String hintText;
  final bool obscureText;
  final int maxLines;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final void Function(String)? onChanged;
  final String? Function(String?)? validator;
  final void Function(String?)? onFieldSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? info;
  final bool isPassword;
  final Widget? suffix;
  final FocusNode? focusNode;
  final bool isRequired;
  final String initialValue;
  final bool enabled;
  final Widget? prefix;
  final bool showOptionalText;
  final int? maxLength;
  final int? minLength;

  @override
  State<CustomTextFieldWithTitle> createState() =>
      _CustomTextFieldWithTitleState();
}

class _CustomTextFieldWithTitleState extends State<CustomTextFieldWithTitle> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ?? TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title.isNotEmpty) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                widget.title,
                style: styles.typography.t2
                    .textColor(styles.theme.textPrimary)
                    .textHeight(0)
                    .medium,
              ),
              Text(
                widget.isRequired
                    ? '\u2055'
                    : widget.showOptionalText
                        ? '(Optional)'
                        : '',
                style: styles.typography.t1
                    .textColor(
                      widget.showOptionalText
                          ? styles.theme.black
                          : styles.theme.red,
                    )
                    .textHeight(-1.2),
              ),
              Expanded(child: Container()),
              if (widget.info != null) widget.info!,
            ],
          ),
          const SizedBox(height: 8),
        ],
        Stack(
          children: [
            CustomTextField(
              focusNode: widget.focusNode,
              controller: _controller,
              hintText: widget.hintText,
              obscureText: widget.obscureText,
              maxLines: widget.maxLines,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              onChanged: widget.onChanged,
              validator: widget.validator,
              inputFormatters: widget.inputFormatters,
              password: widget.isPassword,
              suffix: widget.suffix,
              enabled: widget.enabled,
              prefix: widget.prefix,
              maxLength: widget.maxLength,
              minLength: widget.minLength,
            ),
          ],
        ),
      ],
    );
  }
}

class CustomTextFieldWithIcon extends StatelessWidget {
  const CustomTextFieldWithIcon({
    required this.labelText,
    this.hintText,
    super.key,
    this.controller,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.done,
    this.onChanged,
    this.validator,
    this.inputFormatters,
  });
  final TextEditingController? controller;
  final String? hintText;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int maxLines;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final void Function(String)? onChanged;
  final String Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final String labelText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        labelText: labelText,
        labelStyle: styles.typography.btn.textColor(styles.theme.grey),
      ),
      style: styles.typography.btn,
      validator: validator ??
          (val) {
            if (val!.isEmpty) return "Field can't be empty";
            return null;
          },
    );
  }
}
