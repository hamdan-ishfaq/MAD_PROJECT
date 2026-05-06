import 'package:tripgenie/features/social/models/community_update_model.dart';
import 'package:tripgenie/core/services/local_backend_service.dart';

/// Service for community updates – tips, warnings, and reviews per place.
/// Now uses local SQLite backend instead of HTTP calls.
class CommunityService {
  /// Get all community updates for a place
  static Future<List<CommunityUpdate>> getUpdates(String placeId) async {
    try {
      return await LocalBackendService.getCommunityUpdates(placeId);
    } catch (e) {
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
      return await LocalBackendService.postCommunityUpdate(
        placeId: placeId,
        userId: userId,
        userName: userName,
        userInitials: userInitials,
        text: text,
        updateType: updateType,
      );
    } catch (e) {
      return null;
    }
  }

  /// Like or unlike an update
  static Future<bool> toggleLike(String placeId, String updateId) async {
    try {
      return await LocalBackendService.toggleLike(placeId, updateId);
    } catch (e) {
      return false;
    }
  }

  /// Delete a community update (own updates only)
  static Future<bool> deleteUpdate(String placeId, String updateId) async {
    try {
      return await LocalBackendService.deleteCommunityUpdate(
          placeId, updateId);
    } catch (e) {
      return false;
    }
  }
}
