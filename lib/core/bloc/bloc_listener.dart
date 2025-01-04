import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

class BaBlocListener<B extends BaBloc<S>, S extends BlocState>
    extends StatelessWidget {
  const BaBlocListener({
    required this.listener,
    super.key,
    this.bloc,
    this.listenWhen,
    this.child,
  });
  final B? bloc;
  final BlocWidgetListener<S>? listener;
  final BlocBuilderCondition<S>? listenWhen;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<B, S>(
      bloc: bloc,
      listenWhen: listenWhen,
      key: key,
      listener: (context, state) {
        if (state.isError && (state.error?.showOnSnackBar ?? false) == true) {
          RSnackBar.error(state.error?.message).show(context);
        }
        listener?.call(context, state);
      },
      child: child,
    );
  }
}
