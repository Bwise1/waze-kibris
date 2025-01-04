import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  late String whyDeleteAccount = '';

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
                    'Delete account',
                    style: styles.typography.h3.textColor(styles.theme.text),
                  ),
                  Gap(8 * styles.scale),
                  Text(
                    "We’re so sorry to hear that you're considering "
                    ' leaving us. '
                    "You've been a great part of our community."
                    " Could you please share what's"
                    ' making you think about this decision?',
                    style:
                        styles.typography.hairline.textColor(styles.theme.ash),
                  ),
                  Gap(24 * styles.scale),
                  DeleteAccountActionBtn(
                    onTap: (String d) {
                      whyDeleteAccount = d;
                      setState(() {});
                      return '';
                    },
                    title: 'I don’t use the account anymore',
                    selectedOption: whyDeleteAccount,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Divider(
                      color: styles.theme.secondary,
                    ),
                  ),
                  DeleteAccountActionBtn(
                    onTap: (String d) {
                      whyDeleteAccount = d;
                      setState(() {});
                      return '';
                    },
                    title: 'I am making a device change',
                    selectedOption: whyDeleteAccount,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Divider(
                      color: styles.theme.secondary,
                    ),
                  ),
                  DeleteAccountActionBtn(
                    onTap: (String d) {
                      whyDeleteAccount = d;
                      setState(() {});
                      return '';
                    },
                    title: 'I don’t understand how to use the service',
                    selectedOption: whyDeleteAccount,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Divider(
                      color: styles.theme.secondary,
                    ),
                  ),
                  DeleteAccountActionBtn(
                    onTap: (String d) {
                      whyDeleteAccount = d;
                      setState(() {});
                      return '';
                    },
                    title: 'The services are not available in my city',
                    selectedOption: whyDeleteAccount,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Divider(
                      color: styles.theme.secondary,
                    ),
                  ),
                  DeleteAccountActionBtn(
                    onTap: (String d) {
                      whyDeleteAccount = d;
                      setState(() {});
                      return '';
                    },
                    title: 'Others',
                    selectedOption: whyDeleteAccount,
                  ),
                  Gap(154 * styles.scale),
                  AppBtn.from(
                    onPressed: () {},
                    semanticLabel: '',
                    expand: true,
                    corner: styles.corners.x24,
                    text: 'Delete account',
                    iconColor: styles.theme.primary,
                    bgColor: styles.theme.secondary,
                    padding: EdgeInsets.symmetric(vertical: styles.insets.xs),
                    minimumSize: const Size(0, 56),
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

class DeleteAccountActionBtn extends StatefulWidget {
  const DeleteAccountActionBtn({
    required this.title,
    required this.selectedOption,
    super.key,
    this.onTap,
  });

  final String title;
  final String selectedOption;
  // interaction:
  final String Function(String val)? onTap;

  @override
  State<DeleteAccountActionBtn> createState() => _DeleteAccountActionBtnState();
}

class _DeleteAccountActionBtnState extends State<DeleteAccountActionBtn> {
  @override
  Widget build(BuildContext context) {
    return Row(
      key: widget.key,
      children: [
        AbsorbPointer(
          child: CustomRoundedCheck(
            value: (widget.selectedOption == widget.title) || false,
            onChanged: (v) {},
            color: styles.theme.green,
          ),
        ),
        Gap(
          14 * styles.scale,
        ),
        CustomClickableText(
          onTap: () {
            widget.onTap!(widget.title);
            setState(() {});
          }, //
          text: widget.title,
          style: styles.typography.hairline
              .textColor(styles.theme.text)
              .weight(FontWeight.w500),
        ),
      ],
    );
  }
}
