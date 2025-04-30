import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

class HomeBottomNav extends StatefulWidget {
  const HomeBottomNav({
    required this.onChanged,
    super.key,
    this.index = 0,
  });
  final int index;
  final ValueChanged<int> onChanged;

  @override
  State<HomeBottomNav> createState() => _HomeBottomNavState();
}

class _HomeBottomNavState extends State<HomeBottomNav> {
  late int index;

  @override
  void initState() {
    index = widget.index;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: styles.theme.white,
        boxShadow: styles.shadows.custom(styles.theme.ash, .1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                index = 0;
              });
              widget.onChanged(0);
            },
            child: Container(
              height: 60,
              // width: 53,

              padding: EdgeInsets.all(styles.insets.xs),

              decoration: BoxDecoration(
                color: index == 0
                    ? styles.theme.secondary
                    : styles.theme.transparent,
                borderRadius: BorderRadius.circular(styles.corners.sm),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppIcon(
                    index == 0
                        ? Assets.icons.homeLine
                        : Assets.icons.homeLineRegular,
                    color:
                        index == 0 ? styles.theme.primary : styles.theme.grey,
                    size: 24,
                  ),
                  Text(
                    'Home',
                    style: styles.typography.hairline.textColor(
                      index == 0 ? styles.theme.primary : styles.theme.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                index = 1;
              });
              widget.onChanged(1);
            },
            child: Container(
              height: 60,
              // width: 53,
              padding: EdgeInsets.all(styles.insets.xs),
              decoration: BoxDecoration(
                color: index == 1
                    ? styles.theme.secondary
                    : styles.theme.transparent,
                borderRadius: BorderRadius.circular(styles.corners.sm),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppIcon(
                    Assets.icons.globe,
                    // : Assets.icons.homeLineRegular,
                    color:
                        index == 1 ? styles.theme.primary : styles.theme.grey,
                    size: 24,
                  ),
                  Text(
                    'Reports',
                    style: styles.typography.hairline.textColor(
                      index == 1 ? styles.theme.primary : styles.theme.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                index = 2;
              });
              widget.onChanged(2);
            },
            child: Container(
              height: 60,
              // width: 53, //
              padding: EdgeInsets.all(styles.insets.xs),
              decoration: BoxDecoration(
                color: index == 2
                    ? styles.theme.secondary
                    : styles.theme.transparent,
                borderRadius: BorderRadius.circular(styles.corners.sm),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppIcon(
                    index == 2 ? Assets.icons.user02 : Assets.icons.person,
                    color: index == 2
                        ? styles.theme.primary
                        : styles.theme.grey.withValues(alpha: .5),
                    size: 24,
                  ),
                  Text(
                    'Profile',
                    style: styles.typography.hairline.textColor(
                      index == 2
                          ? styles.theme.primary
                          : styles.theme.grey.withValues(alpha: .5),
                    ),
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
