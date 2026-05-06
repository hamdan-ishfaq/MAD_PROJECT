import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tripgenie/core/services/local_backend_service.dart';
import 'package:tripgenie/features/social/models/trip_model.dart';

/// API service for external APIs and local backend operations.
///
/// Trip operations go through LocalBackendService (SQLite).
/// External API calls (places, weather) still use HTTP directly.
class ApiService {
  // ─── Sample / Fallback places data ───

  static const List<Map<String, dynamic>> _fallbackPlaces = [
    {'id': 'p1', 'name': 'Faisal Mosque', 'category': 'Culture', 'lat': 33.7295, 'lng': 73.0372, 'rating': 4.8, 'crowdLevel': 0.7, 'color': 0xFF6366F1},
    {'id': 'p2', 'name': 'Daman-e-Koh', 'category': 'Parks', 'lat': 33.7384, 'lng': 73.0586, 'rating': 4.5, 'crowdLevel': 0.4, 'color': 0xFF10B981},
    {'id': 'p3', 'name': 'Monal Restaurant', 'category': 'Food', 'lat': 33.7440, 'lng': 73.0640, 'rating': 4.3, 'crowdLevel': 0.8, 'color': 0xFFF59E0B},
    {'id': 'p4', 'name': 'Centaurus Mall', 'category': 'Shopping', 'lat': 33.7085, 'lng': 73.0508, 'rating': 4.1, 'crowdLevel': 0.9, 'color': 0xFFEC4899},
    {'id': 'p5', 'name': 'Pakistan Monument', 'category': 'Culture', 'lat': 33.6932, 'lng': 73.0688, 'rating': 4.7, 'crowdLevel': 0.3, 'color': 0xFF6366F1},
    {'id': 'p6', 'name': 'Trail 3 (Margalla)', 'category': 'Parks', 'lat': 33.7500, 'lng': 73.0650, 'rating': 4.6, 'crowdLevel': 0.5, 'color': 0xFF10B981},
    {'id': 'p7', 'name': 'Lok Virsa Museum', 'category': 'Culture', 'lat': 33.6967, 'lng': 73.0715, 'rating': 4.2, 'crowdLevel': 0.2, 'color': 0xFF6366F1},
    {'id': 'p8', 'name': 'Saidpur Village', 'category': 'Food', 'lat': 33.7397, 'lng': 73.0667, 'rating': 4.4, 'crowdLevel': 0.6, 'color': 0xFFF59E0B},
    {'id': 'p9', 'name': 'Serena Hotel', 'category': 'Hotels', 'lat': 33.7118, 'lng': 73.0901, 'rating': 4.9, 'crowdLevel': 0.4, 'color': 0xFF8B5CF6},
    {'id': 'p10', 'name': 'F-7 Jinnah Super', 'category': 'Shopping', 'lat': 33.7136, 'lng': 73.0575, 'rating': 4.0, 'crowdLevel': 0.7, 'color': 0xFFEC4899},
    {'id': 'p11', 'name': 'Lake View Park', 'category': 'Parks', 'lat': 33.7064, 'lng': 73.1192, 'rating': 4.3, 'crowdLevel': 0.5, 'color': 0xFF10B981},
    {'id': 'p12', 'name': 'Islamabad Zoo', 'category': 'Parks', 'lat': 33.7300, 'lng': 73.0585, 'rating': 3.8, 'crowdLevel': 0.3, 'color': 0xFF10B981},
    {'id': 'p13', 'name': 'NUST Cafe', 'category': 'Food', 'lat': 33.6420, 'lng': 72.9850, 'rating': 4.5, 'crowdLevel': 0.6, 'color': 0xFFF59E0B},
    {'id': 'p14', 'name': 'G-12 Markaz', 'category': 'Shopping', 'lat': 33.6480, 'lng': 72.9920, 'rating': 4.2, 'crowdLevel': 0.8, 'color': 0xFFEC4899},
    {'id': 'p15', 'name': 'NUST Lake', 'category': 'Parks', 'lat': 33.6390, 'lng': 72.9890, 'rating': 4.7, 'crowdLevel': 0.3, 'color': 0xFF10B981},
    {'id': 'p16', 'name': 'NUST Hostel', 'category': 'Hotels', 'lat': 33.6400, 'lng': 72.9800, 'rating': 4.0, 'crowdLevel': 0.5, 'color': 0xFF8B5CF6},
    {'id': 'p17', 'name': 'Savour Foods', 'category': 'Food', 'lat': 33.6520, 'lng': 72.9950, 'rating': 4.8, 'crowdLevel': 0.9, 'color': 0xFFF59E0B},
  ];

  // ─── Places (uses fallback data — no backend needed) ───

  static Future<List<dynamic>> getPlaces() async {
    return _fallbackPlaces;
  }

  /// Synchronous access to fallback places for ID-to-name resolution.
  static List<Map<String, dynamic>> getPlacesSync() {
    return _fallbackPlaces;
  }

  static Future<List<dynamic>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    String? category,
    int radius = 8000,
    int limit = 150,
  }) async {
    if (category != null && category.isNotEmpty && category != 'All') {
      return _fallbackPlaces
          .where((p) =>
              (p['category'] as String).toLowerCase() ==
              category.toLowerCase())
          .toList();
    }
    return _fallbackPlaces;
  }

  // ─── Trips (now uses LocalBackendService) ───

  static Future<List<TripPost>> getTrips({String destination = ''}) async {
    return await LocalBackendService.getTrips(destination: destination);
  }

  static Future<TripPost?> postTrip(Map<String, dynamic> tripData) async {
    try {
      return await LocalBackendService.createTrip(tripData);
    } catch (e) {
      return null;
    }
  }

  // ─── Trending / Discovery (uses fallback data) ───

  static Future<List<dynamic>> getTrendingPlaces({int limit = 10}) async {
    final sorted = List<Map<String, dynamic>>.from(_fallbackPlaces)
      ..sort((a, b) =>
          (b['rating'] as num).compareTo(a['rating'] as num));
    return sorted.take(limit).toList();
  }

  static Future<List<dynamic>> getTopVisitedPlaces({int limit = 10}) async {
    return getTrendingPlaces(limit: limit);
  }
}
