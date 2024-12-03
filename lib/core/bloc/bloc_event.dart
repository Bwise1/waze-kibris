import 'package:flutter/material.dart';

@immutable
abstract class BlocEvent {
  const BlocEvent();
}

@immutable
class ReloadLastEvent extends BlocEvent {
  const ReloadLastEvent() : super();
}