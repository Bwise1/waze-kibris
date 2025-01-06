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
              height: 58,
              width: 53,
              decoration: BoxDecoration(
                color: index == 0
                    ? styles.theme.primary.withValues(alpha: .1)
                    : Colors.transparent,
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
                    style: styles.typography.t3.textColor(
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
              height: 58,
              width: 53,
              decoration: BoxDecoration(
                color: index == 1
                    ? styles.theme.primary.withValues(alpha: .1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(styles.corners.sm),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppIcon(
                    index == 1 ? Assets.icons.user02 : Assets.icons.person,
                    color: index == 1
                        ? styles.theme.primary
                        : styles.theme.grey.withValues(alpha: .5),
                    size: 24,
                  ),
                  Text(
                    'Profile',
                    style: styles.typography.t3.textColor(
                      index == 1
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
