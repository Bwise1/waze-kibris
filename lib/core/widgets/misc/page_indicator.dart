/*
 * Copyright (c) 2024. Relett, Inc.
 *
 */

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:waze_kibris/common.dart';

class CustomPageIndicator extends StatelessWidget {
  const CustomPageIndicator({
    super.key,
    this.isActive = false,
    this.inActiveColor,
    this.activeColor,
  });

  final bool isActive;

  final Color? inActiveColor, activeColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: 300.milliseconds,
      height: isActive ? 12 : 4,
      width: 4,
      decoration: BoxDecoration(
        color: isActive
            ? activeColor ?? styles.theme.primary
            : inActiveColor ?? styles.theme.grey,
        borderRadius: BorderRadius.all(Radius.circular(styles.insets.md)),
      ),
    );
  }
}
