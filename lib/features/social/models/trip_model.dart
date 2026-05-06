// TripPost  - a trip posted by a user for group matching
// ChatMessage - a single message in a trip chat (supports multiple types)

/// The different kinds of chat messages supported.
enum MessageType {
  text,
  image,
  video,
  file,
  review,
  warning,
  system,
}

class TripPost {
  final String id;
  final String userName;
  final String userInitials;
  final String destination;
  final String startDate;
  final String endDate;
  final int groupSize; // max travelers wanted
  final int currentMembers;
  final List<String> interests;
  final String description;
  final String postedAgo;

  TripPost({
    required this.id,
    required this.userName,
    required this.userInitials,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.groupSize,
    required this.currentMembers,
    required this.interests,
    required this.description,
    required this.postedAgo,
  });

  // Spots remaining
  int get spotsLeft => groupSize - currentMembers;
  bool get isFull => spotsLeft <= 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_name': userName,
        'user_initials': userInitials,
        'destination': destination,
        'start_date': startDate,
        'end_date': endDate,
        'group_size': groupSize,
        'current_members': currentMembers,
        'interests': interests,
        'description': description,
        'posted_ago': postedAgo,
      };

  factory TripPost.fromJson(Map<String, dynamic> json) {
    final name = json['user_name']?.toString() ?? 'User';
    return TripPost(
      id: json['id']?.toString() ?? '',
      userName: name,
      userInitials: name.length >= 2
          ? name.substring(0, 2).toUpperCase()
          : name.toUpperCase(),
      destination: json['destination'] ?? 'Unknown',
      startDate: json['start_date'] ?? 'TBD',
      endDate: json['end_date'] ?? 'TBD',
      groupSize: json['group_size'] ?? 4,
      currentMembers: json['current_members'] ?? 1,
      interests: (json['interests'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      description: json['description'] ?? '',
      postedAgo: json['posted_ago'] ?? 'Just now',
    );
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String senderInitials;
  final String text;
  final MessageType messageType;
  final String? mediaPath; // Local file path for images/videos/files
  final String? mediaMimeType; // e.g. 'image/jpeg', 'video/mp4'
  final String? fileName; // Original filename for file transfers
  final int? fileSize; // Size in bytes
  final double? rating; // For review-type messages (1-5 stars)
  final DateTime timestamp;
  final bool isMe; // true = right side (current user)

  ChatMessage({
    required this.id,
    this.senderId = '',
    required this.senderName,
    required this.senderInitials,
    required this.text,
    this.messageType = MessageType.text,
    this.mediaPath,
    this.mediaMimeType,
    this.fileName,
    this.fileSize,
    this.rating,
    required this.timestamp,
    required this.isMe,
  });

  /// Create a copy with updated fields
  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? senderInitials,
    String? text,
    MessageType? messageType,
    String? mediaPath,
    String? mediaMimeType,
    String? fileName,
    int? fileSize,
    double? rating,
    DateTime? timestamp,
    bool? isMe,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderInitials: senderInitials ?? this.senderInitials,
      text: text ?? this.text,
      messageType: messageType ?? this.messageType,
      mediaPath: mediaPath ?? this.mediaPath,
      mediaMimeType: mediaMimeType ?? this.mediaMimeType,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      rating: rating ?? this.rating,
      timestamp: timestamp ?? this.timestamp,
      isMe: isMe ?? this.isMe,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender_id': senderId,
        'sender_name': senderName,
        'sender_initials': senderInitials,
        'text': text,
        'message_type': messageType.name,
        'media_path': mediaPath,
        'media_mime_type': mediaMimeType,
        'file_name': fileName,
        'file_size': fileSize,
        'rating': rating,
        'timestamp': timestamp.toIso8601String(),
        'is_me': isMe,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json,
      {String? currentUserId}) {
    final senderId = json['sender_id']?.toString() ?? '';
    return ChatMessage(
      id: json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: senderId,
      senderName: json['sender_name']?.toString() ??
          json['senderName']?.toString() ??
          json['user_name']?.toString() ??
          'Unknown',
      senderInitials: json['sender_initials']?.toString() ??
          json['senderInitials']?.toString() ??
          json['user_initials']?.toString() ??
          '??',
      text: json['text']?.toString() ?? '',
      messageType: _parseMessageType(
          json['message_type']?.toString() ?? json['type']?.toString()),
      mediaPath: json['media_path']?.toString(),
      mediaMimeType: json['media_mime_type']?.toString(),
      fileName: json['file_name']?.toString(),
      fileSize: json['file_size'] as int?,
      rating: (json['rating'] as num?)?.toDouble(),
      timestamp: DateTime.tryParse(
              json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      isMe: currentUserId != null
          ? senderId == currentUserId
          : (json['is_me'] as bool? ?? json['isMe'] as bool? ?? false),
    );
  }

  static MessageType _parseMessageType(String? type) {
    switch (type) {
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'file':
        return MessageType.file;
      case 'review':
        return MessageType.review;
      case 'warning':
        return MessageType.warning;
      case 'system':
      case 'system_notification':
        return MessageType.system;
      default:
        return MessageType.text;
    }
  }

  /// Human-readable file size
  String get fileSizeFormatted {
    if (fileSize == null) return '';
    if (fileSize! < 1024) return '${fileSize}B';
    if (fileSize! < 1024 * 1024) return '${(fileSize! / 1024).toStringAsFixed(1)}KB';
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

// Hardcoded sample data
class TripRepository {
  static List<TripPost> getSampleTrips() {
    return [
      TripPost(
        id: 't1',
        userName: 'Sara Ahmed',
        userInitials: 'SA',
        destination: 'Istanbul',
        startDate: 'May 10',
        endDate: 'May 17',
        groupSize: 4,
        currentMembers: 2,
        interests: ['History', 'Food', 'Culture'],
        description:
            'Planning a week in Istanbul covering Grand Bazaar, Hagia Sophia, Bosphorus cruise and local food tours. Looking for 2 more travel buddies!',
        postedAgo: '2 hours ago',
      ),
      TripPost(
        id: 't2',
        userName: 'Zain Malik',
        userInitials: 'ZM',
        destination: 'Hunza Valley',
        startDate: 'Jun 1',
        endDate: 'Jun 8',
        groupSize: 6,
        currentMembers: 3,
        interests: ['Nature', 'Adventure', 'Hiking'],
        description:
            'Road trip to Hunza from Islamabad via KKH. Planning to visit Attabad Lake, Eagle\'s Nest and Altit Fort. Budget-friendly shared transport.',
        postedAgo: '5 hours ago',
      ),
      TripPost(
        id: 't3',
        userName: 'Mia Chen',
        userInitials: 'MC',
        destination: 'Bangkok',
        startDate: 'May 20',
        endDate: 'May 27',
        groupSize: 3,
        currentMembers: 1,
        interests: ['Food', 'Shopping', 'Nightlife'],
        description:
            'First time in Bangkok! Want to explore street food scene, weekend markets, temples and maybe a day trip to Ayutthaya.',
        postedAgo: '1 day ago',
      ),
      TripPost(
        id: 't4',
        userName: 'Omar Sheikh',
        userInitials: 'OS',
        destination: 'Skardu',
        startDate: 'Jul 5',
        endDate: 'Jul 12',
        groupSize: 5,
        currentMembers: 4,
        interests: ['Adventure', 'Nature', 'Photography'],
        description:
            'Trekking around Shangrila and Deosai Plains. Camping gear provided. Only 1 spot left — experienced trekkers preferred.',
        postedAgo: '2 days ago',
      ),
    ];
  }
}
