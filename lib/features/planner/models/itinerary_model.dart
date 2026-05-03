class ActivityItem {
  final String time;
  final String title;
  final String description;
  final String type;

  ActivityItem({
    required this.time,
    required this.title,
    required this.description,
    required this.type,
  });

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    return ActivityItem(
      time:        json['time']        ?? '',
      title:       json['title']       ?? '',
      description: json['description'] ?? '',
      type:        json['type']        ?? 'general',
    );
  }
}

class DayPlan {
  final int day;
  final String date;
  final List<ActivityItem> activities;

  DayPlan({
    required this.day,
    required this.date,
    required this.activities,
  });

  factory DayPlan.fromJson(Map<String, dynamic> json) {
    return DayPlan(
      day:  json['day'],
      date: json['date'] ?? '',
      activities: (json['activities'] as List<dynamic>)
          .map((a) => ActivityItem.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Itinerary {
  final String destination;
  final int days;
  final double budget;
  final String summary;
  final List<DayPlan> dayPlans;

  Itinerary({
    required this.destination,
    required this.days,
    required this.budget,
    required this.summary,
    required this.dayPlans,
  });

  factory Itinerary.fromJson(Map<String, dynamic> json) {
    return Itinerary(
      destination: json['destination'] ?? '',
      days:        json['days']        ?? 0,
      budget:      (json['budget'] as num).toDouble(),
      summary:     json['summary']     ?? '',
      dayPlans: (json['day_plans'] as List<dynamic>)
          .map((d) => DayPlan.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }
}
