import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    this.title,
    this.subtitle,
    this.showBackBtn = true,
    this.isTransparent = false,
    this.onBack,
    this.trailing,
    this.backIcon,
    this.backBtnSemantics,
    this.bordered = false,
  });
  final String? title;
  final String? subtitle;
  final bool showBackBtn;
  final String? backIcon;
  final String? backBtnSemantics;
  final bool isTransparent;
  final VoidCallback? onBack;
  final Widget Function(BuildContext context)? trailing;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final icon = backIcon ?? 'Assets.icons.regular.chevronLeft';

    return ColoredBox(
      color: isTransparent ? Colors.transparent : styles.theme.background,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 64 * styles.scale,
          decoration: BoxDecoration(
            border: bordered ?  Border(
              bottom: BorderSide(
                color: styles.theme.grey.withOpacity(0.1),
              ),
            ) : null,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Center(
                  child: Row(
                    children: [
                      if (showBackBtn) ...[
                        BackBtn(
                          onPressed: onBack,
                          icon: icon,
                          semanticLabel: backBtnSemantics,
                          bgColor: Colors.transparent,
                          iconColor: styles.theme.grey,
                        ),
                      ],
                      const Spacer(),
                      if (trailing != null) trailing!.call(context),
                      Gap(styles.insets.sm),
                    ],
                  ),
                ),
              ),
              MergeSemantics(
                child: Semantics(
                  header: true,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: showBackBtn
                              ? MainAxisAlignment.center
                              : MainAxisAlignment.start,
                          children: [
                            Gap(styles.insets.md),
                            if (title != null)
                              Text(
                                title!,
                                textHeightBehavior: const TextHeightBehavior(
                                  applyHeightToFirstAscent: false,
                                ),
                                style: styles.typography.h3
                                    .textColor(styles.theme.textPrimary)
                                    .medium,
                              ),
                          ],
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!.toUpperCase(),
                            textHeightBehavior: const TextHeightBehavior(
                              applyHeightToFirstAscent: false,
                            ),
                            style: styles.typography.t1
                                .copyWith(color: styles.theme.primary),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
