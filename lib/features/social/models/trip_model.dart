// TripPost  - a trip posted by a user for group matching
//  ChatMessage - a single message in a trip chat

class TripPost {
  final String id;
  final String userName;
  final String userInitials;
  final String destination;
  final String startDate;
  final String endDate;
  final int groupSize;         // max travelers wanted
  final int currentMembers;
  final List<String> interests;
  final String description;
  final String postedAgo;      //

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
}

class ChatMessage {
  final String id;
  final String senderName;
  final String senderInitials;
  final String text;
  final DateTime timestamp;
  final bool isMe; // true = right side (current user)

  ChatMessage({
    required this.id,
    required this.senderName,
    required this.senderInitials,
    required this.text,
    required this.timestamp,
    required this.isMe,
  });
}

// Hardcoded sample data (replace with real API in Phase 9)
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

  static List<ChatMessage> getSampleChat(String tripId) {
    return [
      ChatMessage(
        id: 'c1',
        senderName: 'Sara Ahmed',
        senderInitials: 'SA',
        text: 'Hey everyone! Excited to plan this trip together 🎉',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        isMe: false,
      ),
      ChatMessage(
        id: 'c2',
        senderName: 'You',
        senderInitials: 'ME',
        text: 'Just joined! Been wanting to visit Istanbul for years.',
        timestamp:
            DateTime.now().subtract(const Duration(hours: 2, minutes: 30)),
        isMe: true,
      ),
      ChatMessage(
        id: 'c3',
        senderName: 'Sara Ahmed',
        senderInitials: 'SA',
        text:
            'Great! Should we book a riad near the old city? Found some good options on Booking.com',
        timestamp:
            DateTime.now().subtract(const Duration(hours: 2)),
        isMe: false,
      ),
      ChatMessage(
        id: 'c4',
        senderName: 'You',
        senderInitials: 'ME',
        text:
            'Sounds perfect. What\'s the rough budget for accommodation per night?',
        timestamp:
            DateTime.now().subtract(const Duration(hours: 1, minutes: 45)),
        isMe: true,
      ),
      ChatMessage(
        id: 'c5',
        senderName: 'Sara Ahmed',
        senderInitials: 'SA',
        text:
            'I\'m thinking \$30-40 per person per night. Split between 4 it\'s very affordable!',
        timestamp:
            DateTime.now().subtract(const Duration(hours: 1)),
        isMe: false,
      ),
    ];
  }
}
