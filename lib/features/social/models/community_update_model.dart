/// A community update (tip, warning, or review) for a specific place.
class CommunityUpdate {
  final String id;
  final String placeId;
  final String userId;
  final String userName;
  final String userInitials;
  final String text;
  final DateTime timestamp;
  final int likes;
  final bool userLiked;
  final List<String> images;
  final String updateType; // 'tip', 'warning', 'review'

  CommunityUpdate({
    required this.id,
    required this.placeId,
    required this.userId,
    required this.userName,
    required this.userInitials,
    required this.text,
    required this.timestamp,
    required this.likes,
    required this.userLiked,
    required this.images,
    required this.updateType,
  });

  factory CommunityUpdate.fromJson(Map<String, dynamic> json) {
    return CommunityUpdate(
      id: json['id'] ?? '',
      placeId: json['place_id'] ?? '',
      userId: json['user_id'] ?? '',
      userName: json['user_name'] ?? '',
      userInitials: json['user_initials'] ?? 'U',
      text: json['text'] ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      likes: json['likes'] ?? 0,
      userLiked: json['user_liked'] ?? false,
      images: List<String>.from(json['images'] ?? []),
      updateType: json['type'] ?? 'tip',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'place_id': placeId,
      'user_id': userId,
      'user_name': userName,
      'user_initials': userInitials,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'likes': likes,
      'user_liked': userLiked,
      'images': images,
      'type': updateType,
    };
  }
}
