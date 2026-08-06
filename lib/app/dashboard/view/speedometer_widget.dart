import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:waze_kibris/core/services/nav_settings.dart';

class SpeedometerWidget extends StatefulWidget {
  final double currentSpeed; // in m/s
  final double? speedLimit; // in km/h, optional

  const SpeedometerWidget({
    super.key,
    required this.currentSpeed,
    this.speedLimit,
  });

  @override
  State<SpeedometerWidget> createState() => _SpeedometerWidgetState();
}

class _SpeedometerWidgetState extends State<SpeedometerWidget> {
  final FlutterTts _tts = FlutterTts();
  DateTime? _lastSpeedingSpeech;
  bool _wasOverLimit = false;

  @override
  void initState() {
    super.initState();
    _tts.setSpeechRate(0.45);
  }

  @override
  void didUpdateWidget(SpeedometerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final speedKmH = (widget.currentSpeed * 3.6).round();
    final limit = widget.speedLimit;
    if (limit == null || limit <= 0) return;

    final over = speedKmH > limit + 3; // small buffer against GPS jitter
    if (over && !_wasOverLimit) {
      final now = DateTime.now();
      if (_lastSpeedingSpeech == null ||
          now.difference(_lastSpeedingSpeech!) >
              const Duration(seconds: 20)) {
        _lastSpeedingSpeech = now;
        _tts.speak('Slow down. Speed limit $limit kilometers per hour.');
      }
    }
    _wasOverLimit = over;
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final speedKmH = (widget.currentSpeed * 3.6).round();
    final limit = widget.speedLimit;
    final hasLimit = limit != null && limit! > 0;
    final isOverLimit = hasLimit && speedKmH > limit! + 3;
    // Speed limits arrive from Mapbox in km/h; convert both readouts
    // together so the dial and the limit badge never mix units.
    final imperial = NavSettings.units.value == DistanceUnit.imperial;
    final displaySpeed = imperial ? (speedKmH * 0.621371).round() : speedKmH;
    final displayLimit =
        hasLimit ? (imperial ? (limit! * 0.621371).round() : limit!.round()) : 0;
    final unitLabel = imperial ? 'mph' : 'km/h';

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: isOverLimit ? Colors.red : Colors.grey[300]!,
          width: 4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$displaySpeed',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isOverLimit ? Colors.red : Colors.black,
                  height: 1.0,
                ),
              ),
              Text(
                unitLabel,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  height: 1.0,
                ),
              ),
            ],
          ),
          Positioned(
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isOverLimit ? Colors.red : Colors.grey,
                  width: 1,
                ),
              ),
              child: Text(
                hasLimit ? '$displayLimit' : '—',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: isOverLimit ? Colors.red : Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
