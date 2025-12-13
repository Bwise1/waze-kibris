import 'package:equatable/equatable.dart';

class RecentLocation extends Equatable {
  final String placeId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final DateTime lastVisited;
  final int visitCount;
  final String? category;
  final String? iconType;

  const RecentLocation({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.lastVisited,
    this.visitCount = 1,
    this.category,
    this.iconType,
  });

  factory RecentLocation.fromJson(Map<String, dynamic> json) {
    return RecentLocation(
      placeId: json['placeId'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      lastVisited: DateTime.parse(json['lastVisited'] as String),
      visitCount: json['visitCount'] as int? ?? 1,
      category: json['category'] as String?,
      iconType: json['iconType'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'placeId': placeId,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'lastVisited': lastVisited.toIso8601String(),
      'visitCount': visitCount,
      'category': category,
      'iconType': iconType,
    };
  }

  RecentLocation copyWith({
    String? placeId,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    DateTime? lastVisited,
    int? visitCount,
    String? category,
    String? iconType,
  }) {
    return RecentLocation(
      placeId: placeId ?? this.placeId,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastVisited: lastVisited ?? this.lastVisited,
      visitCount: visitCount ?? this.visitCount,
      category: category ?? this.category,
      iconType: iconType ?? this.iconType,
    );
  }

  @override
  List<Object?> get props => [
        placeId,
        name,
        address,
        latitude,
        longitude,
        lastVisited,
        visitCount,
        category,
        iconType,
      ];
}