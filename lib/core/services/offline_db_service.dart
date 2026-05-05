import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tripgenie/core/models/place_model.dart';
import 'package:tripgenie/core/models/dashboard_model.dart';

/// Local SQLite database for offline support (Phase 12).
/// Caches places, itineraries, and favorites locally.
class OfflineDbService {
  static Database? _database;
  static const String _dbName = 'wanderland_offline.db';
  static const int _dbVersion = 1;
  static final StreamController<void> _changesController =
      StreamController<void>.broadcast();
  static final Map<String, Place> _webPlaces = {};
  static final Map<String, SavedItinerary> _webItineraries = {};
  static final Map<String, Map<String, String>> _webFavorites = {};
  static final List<Map<String, dynamic>> _webSyncQueue = [];
  static int _webSyncQueueId = 1;

  static Stream<void> get changes => _changesController.stream;

  static void _notifyChanged() {
    if (!_changesController.isClosed) {
      _changesController.add(null);
    }
  }

  /// Get (or create) the database singleton
  static Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite is not available on web');
    }
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/$_dbName';

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  static Future<String> databasePath() async {
    if (kIsWeb) {
      throw UnsupportedError('Database file path is not available on web');
    }
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_dbName';
  }

  static Future<void> resetDatabaseHandle() async {
    _database = null;
  }

  static Future<void> deleteDatabaseFile() async {
    final path = await databasePath();
    final existingDatabase = _database;
    if (existingDatabase != null) {
      await existingDatabase.close();
    }
    if (await databaseExists(path)) {
      await deleteDatabase(path);
    }
    _database = null;
  }

  static Future<void> _onCreate(Database db, int version) async {
    // Places cache
    await db.execute('''
      CREATE TABLE places (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        category TEXT,
        crowd_level REAL DEFAULT 0,
        rating REAL DEFAULT 0,
        review_count INTEGER DEFAULT 0,
        description TEXT,
        address TEXT,
        phone TEXT,
        website TEXT,
        photos TEXT,
        data TEXT,
        cached_at TEXT
      )
    ''');

    // Saved itineraries
    await db.execute('''
      CREATE TABLE saved_itineraries (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        destination TEXT,
        days INTEGER,
        budget REAL,
        summary TEXT,
        itinerary_json TEXT,
        status TEXT DEFAULT 'planned',
        is_favorite INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Favorites
    await db.execute('''
      CREATE TABLE favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        place_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        added_at TEXT,
        UNIQUE(place_id, user_id)
      )
    ''');

    // Pending sync operations
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation TEXT NOT NULL,
        table_name TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');
  }

  // ─── Places Cache ───

  static Future<void> cachePlaces(List<Place> places) async {
    if (kIsWeb) {
      for (final place in places) {
        _webPlaces[place.id] = place;
      }
      _notifyChanged();
      return;
    }
    final db = await database;
    final batch = db.batch();

    for (final place in places) {
      batch.insert(
        'places',
        {
          'id': place.id,
          'name': place.name,
          'latitude': place.latitude,
          'longitude': place.longitude,
          'category': place.category,
          'crowd_level': place.crowdLevel,
          'rating': place.rating,
          'review_count': place.reviewCount,
          'description': place.description,
          'address': place.address,
          'phone': place.phoneNumber,
          'website': place.website,
          'photos': jsonEncode(place.photos),
          'cached_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  static Future<List<Place>> getCachedPlaces({String? category}) async {
    if (kIsWeb) {
      return _webPlaces.values
          .where((place) => category == null || place.category == category)
          .toList();
    }
    final db = await database;
    final List<Map<String, dynamic>> maps;

    if (category != null) {
      maps = await db
          .query('places', where: 'category = ?', whereArgs: [category]);
    } else {
      maps = await db.query('places');
    }

    return maps.map((map) {
      return Place(
        id: map['id'],
        name: map['name'],
        latitude: map['latitude'] ?? 0.0,
        longitude: map['longitude'] ?? 0.0,
        category: map['category'] ?? 'attraction',
        crowdLevel: map['crowd_level'] ?? 0.0,
        rating: map['rating'] ?? 0.0,
        reviewCount: map['review_count'] ?? 0,
        photos: List<String>.from(jsonDecode(map['photos'] ?? '[]')),
        reviews: [],
        description: map['description'] ?? '',
        address: map['address'] ?? '',
        phoneNumber: map['phone'],
        website: map['website'],
        highlights: [],
        openingHours: [],
        updatedAt: DateTime.tryParse(map['cached_at'] ?? '') ?? DateTime.now(),
      );
    }).toList();
  }

  static Future<Place?> getCachedPlace(String id) async {
    if (kIsWeb) {
      return _webPlaces[id];
    }
    final db = await database;
    final maps = await db.query('places', where: 'id = ?', whereArgs: [id]);

    if (maps.isEmpty) return null;
    final map = maps.first;

    return Place(
      id: map['id'] as String,
      name: map['name'] as String,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] as String? ?? 'attraction',
      crowdLevel: (map['crowd_level'] as num?)?.toDouble() ?? 0.0,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: map['review_count'] as int? ?? 0,
      photos: List<String>.from(jsonDecode(map['photos'] as String? ?? '[]')),
      reviews: [],
      description: map['description'] as String? ?? '',
      address: map['address'] as String? ?? '',
      phoneNumber: map['phone'] as String?,
      website: map['website'] as String?,
      highlights: [],
      openingHours: [],
      updatedAt: DateTime.tryParse(map['cached_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  // ─── Saved Itineraries ───

  static Future<void> saveItineraryLocally(SavedItinerary itinerary) async {
    if (kIsWeb) {
      _webItineraries[itinerary.id] = itinerary;
      _notifyChanged();
      return;
    }
    final db = await database;
    await db.insert(
      'saved_itineraries',
      {
        'id': itinerary.id,
        'user_id': itinerary.userId,
        'destination': itinerary.destination,
        'days': itinerary.days,
        'budget': itinerary.budget,
        'summary': itinerary.summary,
        'itinerary_json': jsonEncode(itinerary.itinerary),
        'status': itinerary.status,
        'is_favorite': itinerary.isFavorite ? 1 : 0,
        'created_at': itinerary.createdAt.toIso8601String(),
        'updated_at': itinerary.updatedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notifyChanged();
  }

  static Future<List<SavedItinerary>> getLocalItineraries(String userId) async {
    if (kIsWeb) {
      return _webItineraries.values
          .where((itinerary) => itinerary.userId == userId)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    final db = await database;
    final maps = await db.query(
      'saved_itineraries',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );

    return maps
        .map((map) => SavedItinerary(
              id: map['id'] as String,
              userId: map['user_id'] as String,
              destination: map['destination'] as String,
              days: map['days'] as int,
              budget: (map['budget'] as num).toDouble(),
              summary: map['summary'] as String? ?? '',
              itinerary: jsonDecode(map['itinerary_json'] as String? ?? '{}'),
              status: map['status'] as String? ?? 'planned',
              isFavorite: (map['is_favorite'] as int?) == 1,
              createdAt:
                  DateTime.tryParse(map['created_at'] as String? ?? '') ??
                      DateTime.now(),
              updatedAt:
                  DateTime.tryParse(map['updated_at'] as String? ?? '') ??
                      DateTime.now(),
            ))
        .toList();
  }

  static Future<void> deleteLocalItinerary(String id) async {
    if (kIsWeb) {
      _webItineraries.remove(id);
      _notifyChanged();
      return;
    }
    final db = await database;
    await db.delete('saved_itineraries', where: 'id = ?', whereArgs: [id]);
    _notifyChanged();
  }

  // ─── Favorites ───

  static Future<void> addLocalFavorite(String userId, String placeId) async {
    if (kIsWeb) {
      _webFavorites.putIfAbsent(userId, () => {})[placeId] = placeId;
      _notifyChanged();
      return;
    }
    final db = await database;
    await db.insert(
      'favorites',
      {
        'place_id': placeId,
        'user_id': userId,
        'added_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    _notifyChanged();
  }

  static Future<void> removeLocalFavorite(String userId, String placeId) async {
    if (kIsWeb) {
      _webFavorites[userId]?.remove(placeId);
      _notifyChanged();
      return;
    }
    final db = await database;
    await db.delete(
      'favorites',
      where: 'place_id = ? AND user_id = ?',
      whereArgs: [placeId, userId],
    );
    _notifyChanged();
  }

  static Future<List<String>> getLocalFavorites(String userId) async {
    if (kIsWeb) {
      return _webFavorites[userId]?.keys.toList() ?? <String>[];
    }
    final db = await database;
    final maps =
        await db.query('favorites', where: 'user_id = ?', whereArgs: [userId]);
    return maps.map((m) => m['place_id'] as String).toList();
  }

  // ─── Sync Queue ───

  static Future<void> addToSyncQueue(
      String operation, String tableName, Map<String, dynamic> data) async {
    if (kIsWeb) {
      _webSyncQueue.add({
        'id': _webSyncQueueId++,
        'operation': operation,
        'table_name': tableName,
        'data': jsonEncode(data),
        'created_at': DateTime.now().toIso8601String(),
        'synced': 0,
      });
      return;
    }
    final db = await database;
    await db.insert('sync_queue', {
      'operation': operation,
      'table_name': tableName,
      'data': jsonEncode(data),
      'created_at': DateTime.now().toIso8601String(),
      'synced': 0,
    });
  }

  static Future<List<Map<String, dynamic>>> getPendingSyncOps() async {
    if (kIsWeb) {
      return _webSyncQueue
          .where((op) => op['synced'] == 0)
          .toList(growable: false);
    }
    final db = await database;
    return await db.query('sync_queue',
        where: 'synced = 0', orderBy: 'created_at ASC');
  }

  static Future<void> markSynced(int id) async {
    if (kIsWeb) {
      final index = _webSyncQueue.indexWhere((op) => op['id'] == id);
      if (index != -1) {
        _webSyncQueue[index]['synced'] = 1;
      }
      return;
    }
    final db = await database;
    await db.update('sync_queue', {'synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  // ─── Utility ───

  static Future<void> clearCache() async {
    if (kIsWeb) {
      _webPlaces.clear();
      return;
    }
    final db = await database;
    await db.delete('places');
  }

  static Future<void> clearAll() async {
    if (kIsWeb) {
      _webPlaces.clear();
      _webItineraries.clear();
      _webFavorites.clear();
      _webSyncQueue.clear();
      return;
    }
    final db = await database;
    await db.delete('places');
    await db.delete('saved_itineraries');
    await db.delete('favorites');
    await db.delete('sync_queue');
  }
}
