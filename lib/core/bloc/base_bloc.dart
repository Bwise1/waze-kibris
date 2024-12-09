import 'package:waze_kibris/common.dart';

abstract class BaBloc<S extends BlocState> extends Bloc<BlocEvent, S> {
  BaBloc({
    required S initialState,
  }) : super(initialState) {
    on<ReloadLastEvent>((_, __) {
      if (_lastHandledEvent == null) {
        throw Exception('cannot add [ReloadLastEvent] as first event!');
      }

      add(_lastHandledEvent!);
    });
  }

  late BlocEvent? _lastHandledEvent;

  void onBlocEvent<E extends BlocEvent>(
    EventHandler<E, S> handler, {
    EventTransformer<E>? transformer,
  }) {
    on<E>(
      (event, emit) async {
        try {
          if (event is! ReloadLastEvent) {
            _lastHandledEvent = event;
          }
          await handler(event, emit);
        } catch (e, stackTrace) {
          safePrint(
            "Unhandled error caught in the $runtimeType! \n Error => $e \n StackTrace => $stackTrace \n",
          );
          emit(state.copyWithErrorPageStateType() as S);
        }
      },
      transformer: transformer,
    );
  }
}
