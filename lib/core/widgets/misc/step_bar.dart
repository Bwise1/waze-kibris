import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:waze_kibris/common.dart';

class StepBar extends StatelessWidget {
  const StepBar({super.key, this.page = 0});
  final int page;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 2,
          width: double.infinity,
          color: styles.theme.nu3,
        ),
        Row(
          mainAxisSize: MainAxisSize.max,
          children: List.generate(7, (index) {
            double widthFactor = (page + 1) / 7;
            Color stepColor;
            if (index == 0) {
              stepColor = styles.theme.red;
            } else if (index == 1) {
              stepColor = styles.theme.red;
            } else if (index == 2) {
              stepColor = styles.theme.grey;
            } else if (index == 3) {
              stepColor = styles.theme.textPrimary;
            } else if (index == 4) {
              stepColor = styles.theme.primary;
            } else if (index == 5) {
              stepColor = styles.theme.secondary;
            } else {
              stepColor = styles.theme.ash;
            }

            return Expanded(
              flex: index <= page ? (widthFactor * 7).toInt() : 0,
              child: AnimatedContainer(
                duration: 400.milliseconds,
                height: 2,
                color: stepColor,
              ),
            );
          }),
        ),
      ],
    );
  }
}
