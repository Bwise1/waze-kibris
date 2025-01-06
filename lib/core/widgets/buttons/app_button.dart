import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:waze_kibris/common.dart';

Widget _buildIcon(
  BuildContext context,
  String icon, {
  required bool isSecondary,
  required double? size,
  Color? iconColor,
}) {
  return AppIcon(
    icon,
    color: iconColor ??
        (isSecondary ? styles.theme.black : styles.theme.background),
    size: size ?? 18,
  );
}

class AppBtn extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  AppBtn({
    required this.onPressed,
    required this.semanticLabel,
    super.key,
    this.enableFeedback = true,
    this.pressEffect = true,
    this.child,
    this.padding,
    this.expand = false,
    this.isSecondary = false,
    this.circular = false,
    this.minimumSize,
    this.bgColor,
    this.border,
    this.corner,
  }) : _builder = null;

  AppBtn.from({
    required this.onPressed,
    super.key,
    this.enableFeedback = true,
    this.pressEffect = true,
    this.padding,
    this.expand = false,
    this.isSecondary = false,
    this.minimumSize,
    this.bgColor,
    this.border,
    String? semanticLabel,
    String? text,
    String? icon,
    double? iconSize,
    Color? iconColor,
    this.corner,
  })  : child = null,
        circular = false {
    if (semanticLabel == null && text == null) {
      throw Exception('AppBtn.from must include either text or semanticLabel');
    }
    this.semanticLabel = semanticLabel ?? text ?? '';
    _builder = (context) {
      if (text == null && icon == null) return const SizedBox.shrink();
      final txt = text == null
          ? null
          : Text(
              text,
              style: styles.typography.btn.textColor(
                iconColor ?? styles.theme.text,
              ),
              textHeightBehavior:
                  const TextHeightBehavior(applyHeightToFirstAscent: false),
            );
      final icn = icon == null
          ? null
          : _buildIcon(
              context,
              icon,
              isSecondary: isSecondary,
              size: iconSize,
              iconColor: iconColor,
            );
      if (txt != null && icn != null) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [txt, Gap(styles.insets.xs), icn],
        );
      } else {
        return (txt ?? icn)!;
      }
    };
  }

  // ignore: prefer_const_constructors_in_immutables
  AppBtn.basic({
    required this.onPressed,
    required this.semanticLabel,
    super.key,
    this.enableFeedback = true,
    this.pressEffect = true,
    this.child,
    this.padding = EdgeInsets.zero,
    this.isSecondary = false,
    this.circular = false,
    this.minimumSize,
    this.corner,
  })  : expand = false,
        bgColor = Colors.transparent,
        border = null,
        _builder = null;

  // interaction:
  final VoidCallback? onPressed;
  late final String semanticLabel;
  final bool enableFeedback;

  // content:
  late final Widget? child;
  late final WidgetBuilder? _builder;

  // layout:
  final EdgeInsets? padding;
  final bool expand;
  final bool circular;
  final Size? minimumSize;
  final double? corner;

  // style:
  final bool isSecondary;
  final BorderSide? border;
  final Color? bgColor;
  final bool pressEffect;

  @override
  Widget build(BuildContext context) {
    final defaultColor =
        isSecondary ? styles.theme.white : styles.theme.primary;
    final textColor = styles.theme.text;
    final side = border ?? BorderSide.none;

    var content = _builder?.call(context) ?? child ?? const SizedBox.shrink();
    if (expand) content = Center(child: content);

    final shape = circular
        ? CircleBorder(side: side)
        : RoundedRectangleBorder(
            side: side,
            borderRadius: BorderRadius.circular(corner ?? styles.corners.md),
          );

    final style = ButtonStyle(
      minimumSize: ButtonStyleButton.allOrNull<Size>(minimumSize ?? Size.zero),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      splashFactory: NoSplash.splashFactory,
      backgroundColor:
          ButtonStyleButton.allOrNull<Color>(bgColor ?? defaultColor),
      overlayColor: ButtonStyleButton.allOrNull<Color>(
        Colors.transparent,
      ), // disable default press effect
      shape: ButtonStyleButton.allOrNull<OutlinedBorder>(shape),
      padding: ButtonStyleButton.allOrNull<EdgeInsetsGeometry>(
        padding ?? EdgeInsets.all(styles.insets.md),
      ),
      enableFeedback: enableFeedback,
    );

    Widget button = _CustomFocusBuilder(
      builder: (context, focus) => Stack(
        children: [
          TextButton(
            onPressed: onPressed,
            style: style,
            focusNode: focus,
            child: DefaultTextStyle(
              style:
                  DefaultTextStyle.of(context).style.copyWith(color: textColor),
              child: content,
            ),
          ),
          if (focus.hasFocus)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(styles.corners.md),
                    border: Border.all(
                      color: styles.theme.secondary,
                      width: 3,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      key: ValueKey(const Uuid().v8()),
    );

    // add press effect:
    if (pressEffect) {
      button = _ButtonPressEffect(
        button,
        key: ValueKey(const Uuid().v8()),
      );
    }

    // add semantics?
    if (semanticLabel.isEmpty) return button;
    return Semantics(
      label: semanticLabel,
      button: true,
      container: true,
      child: ExcludeSemantics(child: button),
    );
  }
}

class _ButtonPressEffect extends StatefulWidget {
  const _ButtonPressEffect(this.child, {super.key});
  final Widget child;

  @override
  State<_ButtonPressEffect> createState() => _ButtonPressEffectState();
}

class _ButtonPressEffectState extends State<_ButtonPressEffect> {
  bool _isDown = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      excludeFromSemantics: true,
      onTapDown: (_) => setState(() => _isDown = true),
      onTapUp: (_) => setState(
        () => _isDown = false,
      ), // not called, TextButton swallows this.
      onTapCancel: () => setState(() => _isDown = false),
      behavior: HitTestBehavior.translucent,
      child: Opacity(
        opacity: _isDown ? 0.7 : 1,
        child: ExcludeSemantics(child: widget.child),
      ),
    );
  }
}

class _CustomFocusBuilder extends StatefulWidget {
  const _CustomFocusBuilder({required this.builder, super.key});
  final Widget Function(BuildContext context, FocusNode focus) builder;

  @override
  State<_CustomFocusBuilder> createState() => _CustomFocusBuilderState();
}

class _CustomFocusBuilderState extends State<_CustomFocusBuilder> {
  late final _focusNode = FocusNode()..addListener(() => setState(() {}));

  @override
  Widget build(BuildContext context) {
    return widget.builder.call(context, _focusNode);
  }
}

/// //////////////////////////////////////////////////
/// CircleBtn
/// RectangleBtn
/// CircleIconBtn
/// BackBtn
/// set of buttons with circular,Rectangle shape & or transparent background
/// //////////////////////////////////////////////////

class CircleBtn extends StatelessWidget {
  const CircleBtn({
    required this.child,
    required this.onPressed,
    required this.semanticLabel,
    super.key,
    this.border,
    this.bgColor,
    this.size,
  });

  static double defaultSize = 45;

  final VoidCallback onPressed;
  final Color? bgColor;
  final BorderSide? border;
  final Widget child;
  final double? size;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final sz = size ?? defaultSize;
    return AppBtn(
      onPressed: onPressed,
      semanticLabel: semanticLabel,
      minimumSize: Size(sz, sz),
      padding: EdgeInsets.zero,
      circular: true,
      bgColor: bgColor,
      border: border,
      child: child,
    );
  }
}

class CircleIconBtn extends StatelessWidget {
  const CircleIconBtn({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    super.key,
    this.border,
    this.bgColor,
    this.color,
    this.size,
    this.iconSize,
  });

  static double defaultSize = 24;

  final String icon;
  final VoidCallback onPressed;
  final BorderSide? border;
  final Color? bgColor;
  final Color? color;
  final String semanticLabel;
  final double? size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final defaultColor = styles.theme.ash;
    final iconColor = color ?? styles.theme.ash;
    return CircleBtn(
      onPressed: onPressed,
      border: border,
      size: size,
      bgColor: bgColor ?? defaultColor,
      semanticLabel: semanticLabel,
      child: AppIcon(icon, size: iconSize ?? defaultSize, color: iconColor),
    );
  }

  Widget safe() => _SafeAreaWithPadding(child: this);
}

class IconBtn extends StatelessWidget {
  const IconBtn({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    super.key,
    this.border,
    this.bgColor,
    this.size,
    this.color,
    this.iconSize = 18,
  });

  static double defaultSize = 44;

  final VoidCallback onPressed;
  final Color? bgColor;
  final BorderSide? border;
  final String icon;
  final double? size;
  final String semanticLabel;
  final double iconSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final sz = size ?? defaultSize;
    return AppBtn(
      onPressed: onPressed,
      semanticLabel: semanticLabel,
      minimumSize: Size(sz, sz),
      padding: EdgeInsets.zero,
      bgColor: bgColor,
      border: border,
      corner: styles.corners.sm,
      child: AppIcon(icon, size: iconSize, color: color),
    );
  }
}

class BackBtn extends StatelessWidget {
  const BackBtn({
    super.key,
    this.icon,
    this.onPressed,
    this.semanticLabel,
    this.bgColor,
    this.iconColor,
    this.iconSize,
    this.borderSide,
  });

  BackBtn.close({
    Key? key,
    VoidCallback? onPressed,
    Color? bgColor,
    Color? iconColor,
  }) : this(
          key: key,
          icon: Assets.icons.close,
          onPressed: onPressed,
          semanticLabel: '',
          bgColor: bgColor ?? Colors.transparent,
          iconColor: iconColor ?? styles.theme.grey,
          borderSide: BorderSide(
            color: styles.theme.nu1,
          ),
        );

  final Color? bgColor;
  final Color? iconColor;
  final String? icon;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final double? iconSize;
  final BorderSide? borderSide;
  @override
  Widget build(BuildContext context) {
    final defaultIcon = icon ?? Assets.icons.chevronLeft;

    return IconBtn(
      icon: defaultIcon,
      bgColor: bgColor,
      color: iconColor,
      iconSize: iconSize ?? 24,
      onPressed: onPressed ?? () => context.pop(),
      semanticLabel: semanticLabel ?? '',
      border: borderSide,
    );
  }

  Widget safe() => _SafeAreaWithPadding(child: this);
}

class _SafeAreaWithPadding extends StatelessWidget {
  const _SafeAreaWithPadding({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.all(styles.insets.sm),
        child: child,
      ),
    );
  }
}
