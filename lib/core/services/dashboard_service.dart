import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tripgenie/core/models/dashboard_model.dart';
import 'package:tripgenie/core/config/network_config.dart';

/// Service for dashboard, favorites, and saved itineraries
class DashboardService {
  static String get _baseUrl => NetworkConfig.baseUrl;

  // ─── Dashboard ───

  static Future<UserDashboard?> getDashboard(String userId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/users/$userId/dashboard'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return UserDashboard.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print('Error fetching dashboard: $e');
      return null;
    }
  }

  // ─── Favorites ───

  static Future<List<String>> getFavorites(String userId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/users/$userId/favorites'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return List<String>.from(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      print('Error fetching favorites: $e');
      return [];
    }
  }

  static Future<bool> addFavorite(String userId, String placeId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/users/$userId/favorites/$placeId'),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      print('Error adding favorite: $e');
      return false;
    }
  }

  static Future<bool> removeFavorite(String userId, String placeId) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$_baseUrl/users/$userId/favorites/$placeId'),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      print('Error removing favorite: $e');
      return false;
    }
  }

  // ─── Saved Itineraries ───

  static Future<SavedItinerary?> saveItinerary({
    required String userId,
    required String destination,
    required int days,
    required double budget,
    required String summary,
    required Map<String, dynamic> itineraryJson,
    String status = 'planned',
  }) async {
    const int maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await http
            .post(
              Uri.parse('$_baseUrl/itineraries/save?user_id=$userId'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'destination': destination,
                'days': days,
                'budget': budget,
                'summary': summary,
                'itinerary_json': itineraryJson,
                'status': status,
              }),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          return SavedItinerary.fromJson(jsonDecode(response.body));
        }

        print('SaveItinerary attempt $attempt failed: ${response.statusCode}');
      } catch (e) {
        print('Error saving itinerary (attempt $attempt): $e');
      }

      if (attempt < maxAttempts) {
        // Exponential backoff
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }

    return null;
  }

  static Future<List<SavedItinerary>> getSavedItineraries(String userId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/users/$userId/itineraries'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data.map((json) => SavedItinerary.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching saved itineraries: $e');
      return [];
    }
  }

  static Future<bool> deleteItinerary(String itineraryId, String userId) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$_baseUrl/itineraries/$itineraryId?user_id=$userId'),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting itinerary: $e');
      return false;
    }
  }
}
