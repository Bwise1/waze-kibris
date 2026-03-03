import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

enum LoaderType { spinner, text }

class CustomLoader extends StatelessWidget {
  const CustomLoader({
    this.type = LoaderType.spinner,
    this.padding = EdgeInsets.zero,
    this.color,
    this.value,
    super.key,
  });
  final LoaderType type;
  final EdgeInsets padding;
  final Color? color;
  final double? value;

  static bool isAndroid = PlatformInfo.isAndroid;

  @override
  Widget build(BuildContext context) {
    // Use contrasting colors: light background on both platforms for visibility
    // iOS was using primary color for background, making it invisible (same as valueColor)
    final bColor = color ?? styles.theme.white;
    switch (type) {
      case LoaderType.spinner:
        return Center(
          child: SizedBox.fromSize(
            size: const Size.square(24),
            child: CircularProgressIndicator.adaptive(
              value: value,
              strokeCap: StrokeCap.round,
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(styles.theme.primary),
              backgroundColor: bColor,
            ),
          ),
        );
      case LoaderType.text:
        return Padding(
          padding: padding,
          child: Center(
            child: Text(
              'Please wait...',
              style: styles.typography.t1,
            ),
          ),
        );
    }
  }
}
