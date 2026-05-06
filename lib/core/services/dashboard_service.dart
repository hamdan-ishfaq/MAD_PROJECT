import 'package:tripgenie/core/models/dashboard_model.dart';
import 'package:tripgenie/core/services/local_backend_service.dart';

/// Service for dashboard, favorites, and saved itineraries.
/// Now uses local SQLite backend instead of HTTP calls.
class DashboardService {
  // ─── Dashboard ───

  static Future<UserDashboard?> getDashboard(String userId) async {
    try {
      return await LocalBackendService.getDashboard(userId);
    } catch (e) {
      return null;
    }
  }

  // ─── Favorites ───

  static Future<List<String>> getFavorites(String userId) async {
    try {
      return await LocalBackendService.getFavorites(userId);
    } catch (e) {
      return [];
    }
  }

  static Future<bool> addFavorite(String userId, String placeId) async {
    try {
      return await LocalBackendService.addFavorite(userId, placeId);
    } catch (e) {
      return false;
    }
  }

  static Future<bool> removeFavorite(String userId, String placeId) async {
    try {
      return await LocalBackendService.removeFavorite(userId, placeId);
    } catch (e) {
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
    try {
      return await LocalBackendService.saveItinerary(
        userId: userId,
        destination: destination,
        days: days,
        budget: budget,
        summary: summary,
        itineraryJson: itineraryJson,
        status: status,
      );
    } catch (e) {
      return null;
    }
  }

  static Future<List<SavedItinerary>> getSavedItineraries(
      String userId) async {
    try {
      return await LocalBackendService.getSavedItineraries(userId);
    } catch (e) {
      return [];
    }
  }

  static Future<bool> deleteItinerary(
      String itineraryId, String userId) async {
    try {
      return await LocalBackendService.deleteItinerary(itineraryId, userId);
    } catch (e) {
      return false;
    }
  }
}
