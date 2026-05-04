import 'package:flutter/material.dart';

class Place {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String category;
  final double crowdLevel;
  final double rating;
  final int reviewCount;
  final List<String> photos;
  final List<Review> reviews;
  final String description;
  final String address;
  final String? phoneNumber;
  final String? website;
  final List<String> highlights;
  final List<PlaceHour> openingHours;
  final String? openNow;
  final DateTime updatedAt;

  Place({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.crowdLevel,
    required this.rating,
    required this.reviewCount,
    required this.photos,
    required this.reviews,
    required this.description,
    required this.address,
    this.phoneNumber,
    this.website,
    required this.highlights,
    required this.openingHours,
    this.openNow,
    required this.updatedAt,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? (json['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? (json['lng'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] ?? 'attraction',
      crowdLevel: (json['crowd_level'] as num?)?.toDouble() ?? (json['crowdLevel'] as num?)?.toDouble() ?? 0.0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['review_count'] ?? 0,
      photos: List<String>.from(json['photos'] ?? []),
      reviews: (json['reviews'] as List?)?.map((r) => Review.fromJson(r)).toList() ?? [],
      description: json['description'] ?? '',
      address: json['address'] ?? '',
      phoneNumber: json['phone'],
      website: json['website'],
      highlights: List<String>.from(json['highlights'] ?? []),
      openingHours: (json['opening_hours'] as List?)?.map((h) => PlaceHour.fromJson(h)).toList() ?? [],
      openNow: json['open_now'],
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  // Get color based on crowd level
  Color get crowdColor {
    if (crowdLevel < 30) return Colors.green;
    if (crowdLevel < 60) return Colors.yellow;
    if (crowdLevel < 80) return Colors.orange;
    return Colors.red;
  }

  String get crowdStatus {
    if (crowdLevel < 30) return 'Not Busy';
    if (crowdLevel < 60) return 'Moderately Busy';
    if (crowdLevel < 80) return 'Busy';
    return 'Very Busy';
  }
}

class Review {
  final String author;
  final double rating;
  final String text;
  final DateTime date;

  Review({
    required this.author,
    required this.rating,
    required this.text,
    required this.date,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      author: json['author'] ?? 'Anonymous',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      text: json['text'] ?? '',
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
    );
  }
}

class PlaceHour {
  final String day;
  final String opens;
  final String closes;

  PlaceHour({
    required this.day,
    required this.opens,
    required this.closes,
  });

  factory PlaceHour.fromJson(Map<String, dynamic> json) {
    return PlaceHour(
      day: json['day'] ?? '',
      opens: json['opens'] ?? '',
      closes: json['closes'] ?? '',
    );
  }
}
