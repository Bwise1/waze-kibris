
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/res/strings.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(

      child:
      // Stack(
      //   fit: StackFit.expand,
      //   children: [
      //     Container(
      //       height: context.heightPx,
      //       width: context.widthPx,
      //       decoration: BoxDecoration(
      //           image: DecorationImage(
      //               image: AssetImage(Assets.images.friendsWithPuzzel.keyName),
      //               fit: BoxFit.cover)),
      //     ),
      //     Positioned(
      //       bottom: 0,
      //       child: UnconstrainedBox(
      //         child: Container(
      //           height: context.heightPx * 0.7,
      //           width: context.widthPx,
      //           decoration: BoxDecoration(
      //               gradient: LinearGradient(
      //                 begin: Alignment.topCenter,
      //                 end: Alignment.bottomCenter,
      //                 colors: [Colors.transparent, Colors.white.withOpacity(0.9)],
      //                 stops: const [0, .4],
      //               )),
      //         ),
      //       ),
      //     ),
      //     SizedBox(
      //       // height: context.heightPx,
      //       // width: context.widthPx,
      //       child: Padding(
      //         padding: EdgeInsets.symmetric(horizontal: 24),
      //         child: Column(
      //           mainAxisAlignment: MainAxisAlignment.end,
      //           children: [
      //             Text(
      //               "R.S.liveLikeALocal",
      //               // style: TextStyles.h4.copyWith(fontSize: 36, height: 0.1),
      //             ),
      //
      //
      //
      //             Padding(
      //               padding: EdgeInsets.symmetric(
      //                   horizontal:24),
      //               child: Text(
      //                " R.S.continueAsGuest",
      //                 style: styles.typography.h2 .copyWith(
      //                     fontWeight: FontWeight.w600,
      //                     decoration: TextDecoration.underline),
      //                 textAlign: TextAlign.center,
      //               ),
      //             ),
      //
      //           ],
      //         ),
      //       ),
      //     )
      //   ],
      // ),

      ///
      Column(
        children: [
          AppHeader(
            backIcon: Assets.icons.backArrow,


            isTransparent: true,
          ),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: styles.insets.lg),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Gap(16*styles.scale),
                  Card(
                    color: Colors.transparent,
                    clipBehavior: Clip.antiAliasWithSaveLayer,
                    elevation: 8,
                    child: Stack(
                      children: [
                        SizedBox(
                          width:context.widthPx,
                          height:120,
                          child: Assets.images.friendsWithPuzzel.image(fit: BoxFit.cover),
                        ),



                        Positioned(
                          bottom: 0,
                          left: 0,
                          child: UnconstrainedBox(
                            child: Container(
                              height: 120  ,
                              width: context.widthPx*0.4 ,
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [   Colors.white, Colors.white.withOpacity(0.7)],
                                    stops: const [0,   0.8],
                                  )),
                            ),
                          ),
                        ),

                        Positioned(
                          bottom: 0,
                          left: context.widthPx*0.4,
                          child: UnconstrainedBox(
                            child: Container(
                              height: 120  ,
                              width: context.widthPx*0.5 ,
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [   Colors.white.withOpacity(0.7), Colors.white.withOpacity(0.15)],
                                    stops: const [0,   0.2],
                                  )),
                            ),
                          ),
                        ),

                        Positioned(
                            left: 25,
                            bottom: 15,
                            child: Text("About Us",style: styles.typography.h2.textColor(styles.theme.text).weight(FontWeight.w600).textHeight(0.9) )),
                      ],
                    ),
                  ),
                  Gap(16*styles.scale),

                  Text(
                    Strings.aboutUsNote,
                    style: styles.typography.hairline.textColor(styles.theme.ash),
                  ) ,








                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
