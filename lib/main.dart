import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

void main() {
  runApp(const MainApp());
  MapboxOptions.setAccessToken(
      'pk.eyJ1IjoiYm5lanlzNTA0IiwiYSI6ImNtYzAzd2thdzJhbzAyaXMzMDM0cXNqbHgifQ.WWh-NiK8VWaoOilR7HYEvw');
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Hello World!'),
        ),
      ),
    );
  }
}
