import 'package:geolocator/geolocator.dart';

class Waypoint {
  final double latitude;
  final double longitude;
  final String? name;
  final String? address;

  const Waypoint({
    required this.latitude,
    required this.longitude,
    this.name,
    this.address,
  });

  factory Waypoint.fromPosition(Position position) {
    return Waypoint(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  Position toPosition() {
    return Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
      accuracy: 0.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );
  }

  double distanceTo(Waypoint other) {
    return Geolocator.distanceBetween(
      latitude,
      longitude,
      other.latitude,
      other.longitude,
    );
  }

  double bearingTo(Waypoint other) {
    return Geolocator.bearingBetween(
      latitude,
      longitude,
      other.latitude,
      other.longitude,
    );
  }

  Waypoint copyWith({
    double? latitude,
    double? longitude,
    String? name,
    String? address,
  }) {
    return Waypoint(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      name: name ?? this.name,
      address: address ?? this.address,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      if (name != null) 'name': name,
      if (address != null) 'address': address,
    };
  }

  factory Waypoint.fromJson(Map<String, dynamic> json) {
    return Waypoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      name: json['name'] as String?,
      address: json['address'] as String?,
    );
  }

  @override
  String toString() {
    return 'Waypoint(lat: $latitude, lng: $longitude, name: $name)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Waypoint &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.name == name &&
        other.address == address;
  }

  @override
  int get hashCode {
    return Object.hash(latitude, longitude, name, address);
  }
}