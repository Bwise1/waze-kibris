import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:waze_kibris/common.dart';

class CustomDialog {
  static Future<void> openBottomSheet(
    BuildContext context,
    Widget child, {
    double sizeFraction = 0.38,
    String title = '',
    bool addCloseIcon = false,
    bool showDragTopICon = false,
    bool centerAlignTitle = true,
    bool isDismissible = true,
    bool enableDrag = true,
    double edgeRadius = 24,
    Color? titleColor,
    double closeIconHeightFromTop = 32,
    EdgeInsets? padding,
  }) {
    return showMaterialModalBottomSheet(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent.withValues(alpha: 0.15),
      builder: (
        BuildContext context,
      ) =>
          CustomContainer(
        height: context.heightPx * sizeFraction,
        color: Theme.of(context).scaffoldBackgroundColor,
        // shadows: styles.,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(edgeRadius),
          topRight: Radius.circular(edgeRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showDragTopICon) ...[
              CustomContainer(
                width: 50,
                height: 5,
                margin: const EdgeInsets.only(top: 1),
                borderRadius: BorderRadius.circular(styles.corners.md),
                color: Colors.black.withValues(alpha: 0.2),
              ),
            ],
            Gap(closeIconHeightFromTop),
            if (title.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (centerAlignTitle) ...[const SizedBox()],

                    Text(
                      title,
                      style: styles.typography.h1.copyWith(
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    // const Spacer(),
                    Visibility(
                      visible: addCloseIcon,
                      child: Icon(
                        Icons.cancel,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Gap(10),
            Expanded(
              child: Padding(
                padding: padding ?? const EdgeInsets.symmetric(horizontal: 24),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
