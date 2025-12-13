import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

class GradientBG extends StatelessWidget {
  const GradientBG({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: context.widthPx,
      height: context.heightPx,
      child: Assets.images.introGradientPng.image(fit: BoxFit.cover),
    );
  }
}
