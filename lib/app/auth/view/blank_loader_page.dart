import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

class BlankLoaderScreen extends StatelessWidget {
  const BlankLoaderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox(
        height: context.heightPx,
        width: context.widthPx,
        child: const Center(
          child: SizedBox(height: 150, width: 150, child: CustomLoader()),
        ),
      ),
    );
  }
}
