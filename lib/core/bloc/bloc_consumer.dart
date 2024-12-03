import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

class BaBlocConsumer<B extends BaBloc<S>, S extends BlocState>
    extends StatefulWidget {
  const BaBlocConsumer({
    required this.builder,
    required this.listener,
    super.key,
    this.errorBuilder,
    this.bloc,
    this.buildWhen,
    this.listenWhen,
    this.showLoading,
    this.showError,
  });
  final B? bloc;
  final BlocWidgetBuilder<S> builder;
  final BlocBuilderCondition<S>? buildWhen;
  final BlocWidgetListener<S>? listener;
  final BlocBuilderCondition<S>? listenWhen;
  final BlocWidgetBuilder<S>? errorBuilder;
  final bool Function(BuildContext, S)? showLoading;
  final bool Function(BuildContext, S)? showError;

  @override
  State<BaBlocConsumer<B, S>> createState() => _BaBlocConsumerState<B, S>();
}

class _BaBlocConsumerState<B extends BaBloc<S>, S extends BlocState>
    extends State<BaBlocConsumer<B, S>> {
  bool? previousStateIsError;

  bool? currentStateIsError;

  bool get shouldShowError =>
      previousStateIsError == false && currentStateIsError == true;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<B, S>(
      bloc: widget.bloc,
      listenWhen: widget.listenWhen,
      buildWhen: widget.buildWhen,
      listener: (context, state) {
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
          RSnackBar.error(state.error?.message).show(context);
        }
        widget.listener?.call(context, state);
      },
      builder: (context, state) {
        if (shouldShowError &&
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
