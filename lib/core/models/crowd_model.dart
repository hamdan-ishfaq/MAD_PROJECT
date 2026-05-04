class CrowdData {
  final String id;
  final String placeId;
  final int crowdLevel;
  final DateTime timestamp;
  final String source;  // 'google', 'user', 'model'
  final String? userId; // if user-reported

  CrowdData({
    required this.id,
    required this.placeId,
    required this.crowdLevel,
    required this.timestamp,
    required this.source,
    this.userId,
  });

  factory CrowdData.fromJson(Map<String, dynamic> json) {
    return CrowdData(
      id: json['id'] ?? '',
      placeId: json['place_id'] ?? '',
      crowdLevel: json['crowd_level'] ?? 0,
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      source: json['source'] ?? 'model',
      userId: json['user_id'],
    );
  }
}
