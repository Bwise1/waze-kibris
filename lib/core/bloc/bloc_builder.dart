import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:waze_kibris/common.dart';

class BaBlocBuilder<B extends BaBloc<S>, S extends BlocState>
    extends StatefulWidget {

  const BaBlocBuilder({
    required this.builder, super.key,
    this.errorBuilder,
    this.bloc,
    this.buildWhen,
    this.showLoading,
    this.showError,
    this.forceHideError,
  });
  final B? bloc;
  final BlocWidgetBuilder<S> builder;
  final BlocBuilderCondition<S>? buildWhen;
  final BlocWidgetBuilder<S>? errorBuilder;
  final bool Function(BuildContext, S)? showLoading;
  final bool Function(BuildContext, S)? showError;
  final bool? forceHideError;

  @override
  State<BaBlocBuilder<B, S>> createState() => _BaBlocBuilderState<B, S>();
}

class _BaBlocBuilderState<B extends BaBloc<S>, S extends BlocState>
    extends State<BaBlocBuilder<B, S>> {
  bool? previousStateIsError;

  bool? currentStateIsError;

  bool get shouldShowError =>
      previousStateIsError == false && currentStateIsError == true;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<B, S>(
      bloc: widget.bloc,
      buildWhen: widget.buildWhen,
      builder: (context, state) {
        if (state.isError) {
          if (currentStateIsError != null) {
            previousStateIsError = currentStateIsError;
            currentStateIsError = true;
          } else {
            currentStateIsError = true;
          }
        } else {
          if (currentStateIsError != null) {
            previousStateIsError = currentStateIsError;
            currentStateIsError = false;
          } else {
            currentStateIsError = false;
          }
        }

        if (shouldShowError &&
            state.isError &&
            state.error?.showOnSnackBar == true &&
            widget.showError?.call(context, state) == true) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            RSnackBar.error(state.error?.message).show(context);
          });
        }

        if (shouldShowError &&
            widget.forceHideError != true &&
            state.isError &&
            state.error?.showOnUI == true &&
            widget.showError?.call(context, state) == true) {
          return widget.errorBuilder?.call(context, state) ??
              DefaultBlocErrorUI<B>(
                bloc: widget.bloc ?? context.read<B>(),
              );
        }

        if (state.isLoading &&
            widget.showLoading?.call(context, state) == true) {
          return const Center(
            child: CustomLoader(),
          );
        }

        return widget.builder(context, state);
      },
    );
  }
}
