/// Represents a connected user nearby (from GET /user/nearby-users).
class NearbyUser {
  const NearbyUser({
    required this.userId,
    required this.latitude,
    required this.longitude,
  });

  final String userId;
  final double latitude;
  final double longitude;

  factory NearbyUser.fromJson(Map<String, dynamic> json) {
    return NearbyUser(
      userId: json['user_id']?.toString() ?? '',
      latitude: (json['latitude'] is num) ? (json['latitude'] as num).toDouble() : 0.0,
      longitude: (json['longitude'] is num) ? (json['longitude'] as num).toDouble() : 0.0,
    );
  }
}
