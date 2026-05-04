/// Dashboard data models
class UserDashboard {
  final int tripsCompleted;
  final int placesVisited;
  final int reviewsContributed;
  final int totalDaysTraveled;
  final int citiesVisited;
  final double totalBudgetSpent;
  final List<String> favoritePlaceIds;
  final int savedItinerariesCount;

  UserDashboard({
    required this.tripsCompleted,
    required this.placesVisited,
    required this.reviewsContributed,
    required this.totalDaysTraveled,
    required this.citiesVisited,
    required this.totalBudgetSpent,
    required this.favoritePlaceIds,
    required this.savedItinerariesCount,
  });

  factory UserDashboard.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>? ?? {};
    return UserDashboard(
      tripsCompleted: stats['trips_completed'] ?? 0,
      placesVisited: stats['places_visited'] ?? 0,
      reviewsContributed: stats['reviews_contributed'] ?? 0,
      totalDaysTraveled: stats['total_days_traveled'] ?? 0,
      citiesVisited: stats['cities_visited'] ?? 0,
      totalBudgetSpent: (stats['total_budget_spent'] as num?)?.toDouble() ?? 0.0,
      favoritePlaceIds: List<String>.from(json['favorite_place_ids'] ?? []),
      savedItinerariesCount: json['saved_itineraries_count'] ?? 0,
    );
  }
}

/// Saved itinerary model
class SavedItinerary {
  final String id;
  final String userId;
  final String destination;
  final int days;
  final double budget;
  final String summary;
  final Map<String, dynamic> itinerary;
  final String status; // 'planned', 'ongoing', 'completed'
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  SavedItinerary({
    required this.id,
    required this.userId,
    required this.destination,
    required this.days,
    required this.budget,
    required this.summary,
    required this.itinerary,
    required this.status,
    required this.isFavorite,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SavedItinerary.fromJson(Map<String, dynamic> json) {
    return SavedItinerary(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      destination: json['destination'] ?? '',
      days: json['days'] ?? 0,
      budget: (json['budget'] as num?)?.toDouble() ?? 0.0,
      summary: json['summary'] ?? '',
      itinerary: json['itinerary'] ?? {},
      status: json['status'] ?? 'planned',
      isFavorite: json['is_favorite'] ?? false,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }
}
