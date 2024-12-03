import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

class DefaultBlocErrorUI<B extends BaBloc> extends StatelessWidget {
  final B bloc;

  const DefaultBlocErrorUI({
    required this.bloc,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: styles.insets.lg),
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                bloc.state.error?.message ?? 'An unknown error has occurred',
                textAlign: TextAlign.center,
                maxLines: 10,
                overflow: TextOverflow.ellipsis,
              ),
              Gap(styles.insets.sm),
              //todo:
              // BaActionButton(
              //   title: 'Retry',
              //   onPressed: () {
              //     bloc.add(const ReloadLastEvent());
              //   },
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
