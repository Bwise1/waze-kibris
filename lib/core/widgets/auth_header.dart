import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

class AuthHeader extends StatelessWidget {
  const AuthHeader({required this.header, required this.subHeader, super.key});
  final String header;
  final String subHeader;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(header, style: styles.typography.h1),
        Gap(styles.insets.xs),
        Text(
          subHeader,
          style: styles.typography.t1.textColor(styles.theme.ash).regular,
        ),
      ],
    );
  }
}
