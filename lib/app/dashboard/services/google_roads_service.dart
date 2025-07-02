import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class GoogleRoadsService {
  static const String _baseUrl = 'https://roads.googleapis.com/v1';
  
  /// Snap points to roads using Google Roads API
  Future<List<PointLatLng>> snapToRoads(
    List<PointLatLng> points,
    String apiKey, {
    bool interpolate = true,
  }) async {
    try {
      // Convert points to path parameter
      final path = points
          .map((p) => '${p.latitude},${p.longitude}')
          .join('|');

      final url = Uri.parse('$_baseUrl/snapToRoads')
          .replace(queryParameters: {
        'path': path,
        'interpolate': interpolate.toString(),
        'key': apiKey,
      });

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final snappedPoints = data['snappedPoints'] as List;

        return snappedPoints.map<PointLatLng>((point) {
          final location = point['location'];
          return PointLatLng(
            location['latitude'],
            location['longitude'],
          );
        }).toList();
      } else {
        debugPrint('Google Roads API error: ${response.statusCode}');
        return points; // Return original points on error
      }
    } catch (e) {
      debugPrint('Error calling Google Roads API: $e');
      return points; // Return original points on error
    }
  }

  /// Get speed limits for points using Google Roads API
  Future<List<SpeedLimit>> getSpeedLimits(
    List<PointLatLng> points,
    String apiKey,
  ) async {
    try {
      // First snap to roads to get place IDs
      final snappedResponse = await snapToRoads(points, apiKey);
      
      // This is a simplified version - in practice you'd need to handle place IDs
      // from the snapToRoads response and then call the speedLimits endpoint
      
      return []; // Placeholder
    } catch (e) {
      debugPrint('Error getting speed limits: $e');
      return [];
    }
  }

  /// Enhance polyline with road-snapped points
  Future<EnhancedPolyline> enhancePolyline(
    String encodedPolyline,
    String apiKey,
  ) async {
    try {
      // Decode the polyline
      final polylinePoints = PolylinePoints();
      final decodedPoints = polylinePoints.decodePolyline(encodedPolyline);

      if (decodedPoints.isEmpty) {
        return EnhancedPolyline(
          originalPoints: [],
          snappedPoints: [],
          speedLimits: [],
        );
      }

      // Snap to roads in chunks (Google Roads API has a 100-point limit)
      const chunkSize = 100;
      List<PointLatLng> allSnappedPoints = [];

      for (int i = 0; i < decodedPoints.length; i += chunkSize) {
        final chunk = decodedPoints.sublist(
          i,
          i + chunkSize < decodedPoints.length 
              ? i + chunkSize 
              : decodedPoints.length,
        );

        final snappedChunk = await snapToRoads(chunk, apiKey);
        allSnappedPoints.addAll(snappedChunk);
      }

      // Get speed limits for snapped points
      final speedLimits = await getSpeedLimits(allSnappedPoints, apiKey);

      return EnhancedPolyline(
        originalPoints: decodedPoints,
        snappedPoints: allSnappedPoints,
        speedLimits: speedLimits,
      );
    } catch (e) {
      debugPrint('Error enhancing polyline: $e');
      return EnhancedPolyline(
        originalPoints: [],
        snappedPoints: [],
        speedLimits: [],
      );
    }
  }
}

/// Enhanced polyline with road-snapped data
class EnhancedPolyline {
  final List<PointLatLng> originalPoints;
  final List<PointLatLng> snappedPoints;
  final List<SpeedLimit> speedLimits;

  EnhancedPolyline({
    required this.originalPoints,
    required this.snappedPoints,
    required this.speedLimits,
  });
}

/// Speed limit information for a road segment
class SpeedLimit {
  final String placeId;
  final double speedLimitKph;
  final String units;

  SpeedLimit({
    required this.placeId,
    required this.speedLimitKph,
    required this.units,
  });
}

/// Configuration for road snapping behavior
class SnapToRoadConfig {
  final double snapDistanceThreshold;
  final double offRouteThreshold;
  final double smoothingFactor;
  final bool enableSpeedLimits;
  final bool enableInterpolation;
  final int maxPointsPerRequest;

  const SnapToRoadConfig({
    this.snapDistanceThreshold = 50.0, // meters
    this.offRouteThreshold = 100.0, // meters
    this.smoothingFactor = 0.7,
    this.enableSpeedLimits = false,
    this.enableInterpolation = true,
    this.maxPointsPerRequest = 100,
  });

  static const SnapToRoadConfig wazeStyle = SnapToRoadConfig(
    snapDistanceThreshold: 30.0,
    offRouteThreshold: 75.0,
    smoothingFactor: 0.8,
    enableSpeedLimits: true,
    enableInterpolation: true,
  );
}