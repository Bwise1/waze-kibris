import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

class AddLocationScreen extends StatefulWidget {
  const AddLocationScreen({super.key});

  @override
  State<AddLocationScreen> createState() => _AddLocationScreenState();
}

class _AddLocationScreenState extends State<AddLocationScreen> {
  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Column(
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
                  Gap(16 * styles.scale),
                  Text(
                    'Add a new location',
                    style: styles.typography.h3.textColor(styles.theme.text),
                  ),
                  Gap(8 * styles.scale),
                  Text(
                    '''
Have a new location you want to save? add a new location here and in a minute''',
                    style:
                        styles.typography.hairline.textColor(styles.theme.ash),
                  ),
                  Gap(2 * styles.scale),
                  CustomTextField(
                    hintText: 'find new location',
                    initialValue: ' ',
                    prefix: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconBtn(
                          icon: Assets.icons.searchGlass,
                          bgColor: Colors.transparent,
                          color: styles.theme.text,
                          onPressed: () {},
                          semanticLabel: 'Glass',
                        ),
                        Text(
                          '|',
                          style:
                              styles.typography.h4.textColor(styles.theme.ash),
                        ),
                      ],
                    ),
                    suffix: Assets.icons.mapMarker.image(height: 24, width: 24),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
