import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class SpeedometerWidget extends StatelessWidget {
  final double currentSpeed; // in m/s
  final double? speedLimit; // in km/h, optional

  const SpeedometerWidget({
    super.key,
    required this.currentSpeed,
    this.speedLimit,
  });

  @override
  Widget build(BuildContext context) {
    // Convert m/s to km/h
    final speedKmH = (currentSpeed * 3.6).round();
    final limit = speedLimit ?? 50; // Default mock limit
    final isOverLimit = speedKmH > limit;

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
                '$speedKmH',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isOverLimit ? Colors.red : Colors.black,
                  height: 1.0,
                ),
              ),
              const Text(
                'km/h',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  height: 1.0,
                ),
              ),
            ],
          ),
          // Speed limit badge (mocked for now)
          Positioned(
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red, width: 1),
              ),
              child: Text(
                '$limit',
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
