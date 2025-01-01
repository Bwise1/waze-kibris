import 'package:flutter/material.dart';

import 'package:waze_kibris/common.dart';
class SocialMediaBtn extends StatelessWidget {
  const SocialMediaBtn({
      required this.title, this.socialIcon, super.key, this.onPressed, this.bgColor,
  });
final String? socialIcon;
final String title;
  final VoidCallback? onPressed;

  final Color?bgColor;
  @override
  Widget build(BuildContext context) {
    final icon = socialIcon ?? 'Assets.icons.regular.chevronLeft';

    return SizedBox(
      height: 56,
      child: AppBtn(
        padding: EdgeInsets.all(styles.insets.sm),
        corner: styles.corners.lg,
        onPressed: onPressed,
        minimumSize: const Size(900, 50),
        bgColor:bgColor??styles.theme.background ,
        semanticLabel: 'social-media-text',
        child:  Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              icon,
              width:24,
              height:24,
            ), Gap(styles.insets.xs),Text(title, style: styles.typography.t3.copyWith(fontWeight: FontWeight.w300,color:styles.theme.text),)


          ],),
      ),
    );




      AppBtn.basic(
      onPressed: () {},
      semanticLabel: '',
      corner: styles.corners.lg,


      child: Row(
       mainAxisAlignment: MainAxisAlignment.center,
        children: [
        SvgPicture.asset(
          icon,
          width:24,
          height:24,
        ), Gap(styles.insets.xs),Text(title, style: styles.typography.t3.copyWith(fontWeight: FontWeight.w300,color:styles.theme.text),)


      ],),
      padding: EdgeInsets.symmetric(vertical: styles.insets.xs),
      minimumSize: const Size(0, 56),
    );
  }
}
