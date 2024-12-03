import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

class CustomLogo extends StatelessWidget {
  const CustomLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      width: 120,
      decoration: BoxDecoration(
        color: styles.theme.secondary,
        borderRadius: BorderRadius.circular(styles.corners.lg),
      ),
    );
  }
}
