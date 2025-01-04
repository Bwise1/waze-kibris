import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    this.text,
    this.onPressed,
    this.isLoading = false,
    this.bgColor,
    this.textColor,
  });
  final String? text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? bgColor;
  final Color? textColor;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: AppBtn(
        padding: EdgeInsets.all(styles.insets.sm),
        onPressed: onPressed,
        minimumSize: const Size(900, 50),
        bgColor: bgColor,
        semanticLabel: 'primary-button-text',
        child: isLoading
            ? const SizedBox(height: 18, width: 18, child: CustomLoader())
            : Text(
                text ?? '',
                style: styles.typography.btn
                    .textColor(textColor ?? styles.theme.white),
              ),
      ),
    );
  }
}
