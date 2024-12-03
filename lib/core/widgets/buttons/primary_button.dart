import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    this.text,
    this.onPressed,
    this.isLoading = false,
  });
  final String? text;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: AppBtn(
        padding: EdgeInsets.all(styles.insets.sm),
        onPressed: onPressed,
        minimumSize: Size(900, 50),
        semanticLabel: 'primary-button-text',
        child: isLoading
            ? SizedBox(height: 18, width: 18, child: const CustomLoader())
            : Text(
                text ?? '',
                style: styles.typography.btn.textColor(styles.theme.grey),
              ),
      ),
    );
  }
}
