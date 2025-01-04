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
      (previousStateIsError ?? false) == false &&
      (currentStateIsError ?? false) == true;

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
            (state.error?.showOnSnackBar ?? false) == true &&
            (widget.showError?.call(context, state) ?? false) == true) {
          RSnackBar.error(state.error?.message).show(context);
        }
        widget.listener?.call(context, state);
      },
      builder: (context, state) {
        if (shouldShowError &&
            state.isError &&
           ( state.error?.showOnUI ?? false) == true &&
            (widget.showError?.call(context, state) ?? false)== true) {
          return widget.errorBuilder?.call(context, state) ??
              DefaultBlocErrorUI<B>(
                bloc: widget.bloc ?? context.read<B>(),
              );
        }

        if (state.isLoading &&
            (widget.showLoading?.call(context, state) ?? false) == true) {
          return const Center(
            child: CustomLoader(),
          );
        }

        return widget.builder(context, state);
      },
    );
  }
}
