class WsReportUpdate {
  WsReportUpdate({
    required this.id,
    required this.userId,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.active,
    required this.resolved,
    required this.upvotesCount,
    required this.downvotesCount,
  });

  final int id;
  final String userId;
  final String type;
  final double latitude;
  final double longitude;
  final bool active;
  final bool resolved;
  final int upvotesCount;
  final int downvotesCount;

  factory WsReportUpdate.fromJson(Map<String, dynamic> json) => WsReportUpdate(
        id: (json['id'] as num).toInt(),
        userId: json['user_id'] as String,
        type: json['type'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        active: json['active'] as bool,
        resolved: json['resolved'] as bool,
        upvotesCount: (json['upvotes_count'] as num).toInt(),
        downvotesCount: (json['downvotes_count'] as num).toInt(),
      );
}

