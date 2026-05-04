import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tripgenie/features/social/models/community_update_model.dart';
import 'package:tripgenie/core/config/network_config.dart';

/// Service for community updates – tips, warnings, and reviews per place.
class CommunityService {
  static String get _baseUrl => NetworkConfig.baseUrl;

  /// Get all community updates for a place
  static Future<List<CommunityUpdate>> getUpdates(String placeId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/places/$placeId/updates'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => CommunityUpdate.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching community updates: $e');
      return [];
    }
  }

  /// Post a new community update
  static Future<CommunityUpdate?> postUpdate({
    required String placeId,
    required String userId,
    required String userName,
    required String userInitials,
    required String text,
    required String updateType, // 'tip', 'warning', 'review'
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/places/$placeId/updates'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'place_id': placeId,
          'user_id': userId,
          'user_name': userName,
          'user_initials': userInitials,
          'text': text,
          'type': updateType,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CommunityUpdate.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print('Error posting community update: $e');
      return null;
    }
  }

  /// Like or unlike an update
  static Future<bool> toggleLike(String placeId, String updateId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/places/$placeId/updates/$updateId/like'),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('Error toggling like: $e');
      return false;
    }
  }

  /// Delete a community update (own updates only)
  static Future<bool> deleteUpdate(String placeId, String updateId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/places/$placeId/updates/$updateId'),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting update: $e');
      return false;
    }
  }
}
