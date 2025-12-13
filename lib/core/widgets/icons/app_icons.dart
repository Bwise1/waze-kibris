import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

class AppIcon extends StatelessWidget {
  const AppIcon(this.icon, {super.key, this.size = 22, this.color});
  final String icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: SvgPicture.asset(
          icon,
          width: size,
          height: size,
          theme: SvgTheme(
            currentColor: color ?? styles.theme.ash,
          ),
          colorFilter: ColorFilter.mode(
            color ?? styles.theme.ash,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}
