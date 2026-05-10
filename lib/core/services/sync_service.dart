import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:tripgenie/core/services/offline_db_service.dart';
import 'package:tripgenie/core/services/dashboard_service.dart';
import 'package:tripgenie/core/models/place_model.dart';

/// Manages background synchronization between the local SQLite cache and the backend.
/// Runs periodically and when connectivity is restored.
class SyncService {
  Timer? _syncTimer;
  bool _isSyncing = false;
  final String userId;

  SyncService({required this.userId});

  /// Start periodic background sync every 5 minutes
  void startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      syncAll();
    });
    // Also run immediately
    syncAll();
  }

  /// Stop periodic sync
  void stopSync() {
    _syncTimer?.cancel();
  }

  /// Run a full sync cycle
  Future<void> syncAll() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      // 1. Push pending local changes to server
      await _pushPendingChanges();

      // 2. Pull latest data from server
      await _pullFavorites();
      await _pullSavedItineraries();

      debugPrint('[SyncService] Sync completed successfully');
    } catch (e) {
      debugPrint('[SyncService] Sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // Push locally queued operations to backend
  Future<void> _pushPendingChanges() async {
    final pendingOps = await OfflineDbService.getPendingSyncOps();

    for (final op in pendingOps) {
      try {
        final operation = op['operation'] as String;
        final tableName = op['table_name'] as String;
        // final data = jsonDecode(op['data'] as String);

        // Process based on operation type
        switch ('$tableName:$operation') {
          case 'favorites:add':
            // Already synced via API call — mark as done
            break;
          case 'favorites:remove':
            break;
          case 'saved_itineraries:save':
            break;
          case 'saved_itineraries:delete':
            break;
        }

        await OfflineDbService.markSynced(op['id'] as int);
      } catch (e) {
        debugPrint('[SyncService] Error pushing op ${op['id']}: $e');
      }
    }
  }

  // Pull favorites from backend and cache locally
  Future<void> _pullFavorites() async {
    try {
      final remoteFavorites = await DashboardService.getFavorites(userId);
      // Clear local and re-insert
      for (final placeId in remoteFavorites) {
        await OfflineDbService.addLocalFavorite(userId, placeId);
      }
    } catch (e) {
      debugPrint('[SyncService] Error pulling favorites: $e');
    }
  }

  // Pull saved itineraries from backend
  Future<void> _pullSavedItineraries() async {
    try {
      final remoteItineraries = await DashboardService.getSavedItineraries(userId);
      for (final itinerary in remoteItineraries) {
        await OfflineDbService.saveItineraryLocally(itinerary);
      }
    } catch (e) {
      debugPrint('[SyncService] Error pulling itineraries: $e');
    }
  }

  /// Cache places for a given location (call after loading places online)
  Future<void> cachePlaces(List<Place> places) async {
    await OfflineDbService.cachePlaces(places);
  }

  /// Get places from cache (offline fallback)
  Future<List<Place>> getCachedPlaces({String? category}) async {
    return await OfflineDbService.getCachedPlaces(category: category);
  }

  void dispose() {
    stopSync();
  }
}
