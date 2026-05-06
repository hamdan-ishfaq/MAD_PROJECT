import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:tripgenie/features/social/models/trip_model.dart';
import 'package:tripgenie/features/social/models/community_update_model.dart';
import 'package:tripgenie/core/models/dashboard_model.dart';

/// Pure-Dart backend that replaces the Python FastAPI server.
///
/// All data is persisted in a local SQLite database so nothing
/// is lost on restart. External API calls (Groq, OpenWeatherMap, OpenTripMap)
/// are handled by their respective existing services directly from Flutter.
class LocalBackendService {
  static Database? _database;
  static const String _dbName = 'wanderland_backend.db';
  static const int _dbVersion = 2;
  static const _uuid = Uuid();

  // ─── Database Setup ───

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite backend is not available on web');
    }
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/$_dbName';

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        token TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE trips (
        id TEXT PRIMARY KEY,
        destination TEXT NOT NULL,
        start_date TEXT,
        end_date TEXT,
        group_size INTEGER DEFAULT 4,
        current_members INTEGER DEFAULT 1,
        interests TEXT,
        description TEXT,
        user_name TEXT,
        user_id TEXT,
        posted_ago TEXT DEFAULT 'Just now',
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_messages (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        sender_id TEXT,
        sender_name TEXT,
        sender_initials TEXT,
        text TEXT,
        message_type TEXT DEFAULT 'text',
        media_path TEXT,
        media_mime_type TEXT,
        file_name TEXT,
        file_size INTEGER,
        rating REAL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (trip_id) REFERENCES trips(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE community_updates (
        id TEXT PRIMARY KEY,
        place_id TEXT NOT NULL,
        user_id TEXT,
        user_name TEXT,
        user_initials TEXT,
        text TEXT,
        type TEXT DEFAULT 'tip',
        likes INTEGER DEFAULT 0,
        user_liked INTEGER DEFAULT 0,
        images TEXT,
        timestamp TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        place_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        added_at TEXT,
        UNIQUE(place_id, user_id)
      )
    ''');

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

    await db.execute('''
      CREATE TABLE user_stats (
        user_id TEXT PRIMARY KEY,
        trips_completed INTEGER DEFAULT 0,
        places_visited INTEGER DEFAULT 0,
        reviews_contributed INTEGER DEFAULT 0,
        total_days_traveled INTEGER DEFAULT 0,
        cities_visited INTEGER DEFAULT 0,
        total_budget_spent REAL DEFAULT 0.0
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        user_id TEXT,
        user_name TEXT,
        category TEXT,
        description TEXT,
        amount REAL NOT NULL,
        currency TEXT DEFAULT 'USD',
        paid_by TEXT,
        split_type TEXT DEFAULT 'equal',
        created_at TEXT,
        FOREIGN KEY (trip_id) REFERENCES trips(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE notifications (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT,
        type TEXT DEFAULT 'info',
        related_id TEXT,
        is_read INTEGER DEFAULT 0,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE emergency_contacts (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        relationship TEXT,
        is_local_service INTEGER DEFAULT 0,
        destination TEXT,
        created_at TEXT
      )
    ''');

    // Seed demo user
    await _seedDemoUser(db);
  }

  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new tables for v2
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table'");
      final existingTables =
          tables.map((t) => t['name'] as String).toSet();

      if (!existingTables.contains('expenses')) {
        await db.execute('''
          CREATE TABLE expenses (
            id TEXT PRIMARY KEY,
            trip_id TEXT NOT NULL,
            user_id TEXT,
            user_name TEXT,
            category TEXT,
            description TEXT,
            amount REAL NOT NULL,
            currency TEXT DEFAULT 'USD',
            paid_by TEXT,
            split_type TEXT DEFAULT 'equal',
            created_at TEXT
          )
        ''');
      }
      if (!existingTables.contains('notifications')) {
        await db.execute('''
          CREATE TABLE notifications (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            title TEXT NOT NULL,
            body TEXT,
            type TEXT DEFAULT 'info',
            related_id TEXT,
            is_read INTEGER DEFAULT 0,
            created_at TEXT
          )
        ''');
      }
      if (!existingTables.contains('emergency_contacts')) {
        await db.execute('''
          CREATE TABLE emergency_contacts (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            name TEXT NOT NULL,
            phone TEXT NOT NULL,
            relationship TEXT,
            is_local_service INTEGER DEFAULT 0,
            destination TEXT,
            created_at TEXT
          )
        ''');
      }
    }
  }

  static Future<void> _seedDemoUser(Database db) async {
    final hash = _hashPassword('password123');
    await db.insert(
      'users',
      {
        'id': 'user_1',
        'name': 'Demo User',
        'email': 'demo@example.com',
        'password_hash': hash,
        'token': 'demo-token-${_uuid.v4()}',
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  // ─── Auth ───

  static String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  static String _generateToken(String email) {
    final payload = '$email-${DateTime.now().millisecondsSinceEpoch}';
    return sha256.convert(utf8.encode(payload)).toString();
  }

  static Future<Map<String, dynamic>?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final db = await database;

    // Check if email exists
    final existing =
        await db.query('users', where: 'email = ?', whereArgs: [email]);
    if (existing.isNotEmpty) return null; // Email taken

    final id = 'user_${_uuid.v4().substring(0, 8)}';
    final hash = _hashPassword(password);
    final token = _generateToken(email);

    await db.insert('users', {
      'id': id,
      'name': name,
      'email': email,
      'password_hash': hash,
      'token': token,
      'created_at': DateTime.now().toIso8601String(),
    });

    // Initialize stats for the new user
    await db.insert(
      'user_stats',
      {'user_id': id},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    return {'id': id, 'name': name, 'email': email, 'token': token};
  }

  static Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
  }) async {
    final db = await database;
    final hash = _hashPassword(password);

    final results = await db.query(
      'users',
      where: 'email = ? AND password_hash = ?',
      whereArgs: [email, hash],
    );

    if (results.isEmpty) return null;

    final user = results.first;
    final token = _generateToken(email);

    // Update token
    await db.update(
      'users',
      {'token': token},
      where: 'id = ?',
      whereArgs: [user['id']],
    );

    return {
      'id': user['id'],
      'name': user['name'],
      'email': user['email'],
      'token': token,
    };
  }

  // ─── Trips ───

  static Future<List<TripPost>> getTrips({String destination = ''}) async {
    final db = await database;
    List<Map<String, dynamic>> results;

    if (destination.isNotEmpty) {
      results = await db.query(
        'trips',
        where: 'destination LIKE ?',
        whereArgs: ['%$destination%'],
        orderBy: 'created_at DESC',
      );
    } else {
      results = await db.query('trips', orderBy: 'created_at DESC');
    }

    return results.map((row) {
      return TripPost(
        id: row['id'] as String,
        userName: row['user_name'] as String? ?? 'User',
        userInitials: _initials(row['user_name'] as String? ?? 'U'),
        destination: row['destination'] as String,
        startDate: row['start_date'] as String? ?? 'TBD',
        endDate: row['end_date'] as String? ?? 'TBD',
        groupSize: row['group_size'] as int? ?? 4,
        currentMembers: row['current_members'] as int? ?? 1,
        interests: _decodeList(row['interests'] as String?),
        description: row['description'] as String? ?? '',
        postedAgo: row['posted_ago'] as String? ?? 'Just now',
      );
    }).toList();
  }

  static Future<TripPost> createTrip(Map<String, dynamic> data) async {
    final db = await database;
    final id = _uuid.v4();

    await db.insert('trips', {
      'id': id,
      'destination': data['destination'],
      'start_date': data['start_date'],
      'end_date': data['end_date'],
      'group_size': data['group_size'] ?? 4,
      'current_members': 1,
      'interests': jsonEncode(data['interests'] ?? []),
      'description': data['description'] ?? '',
      'user_name': data['user_name'] ?? 'User',
      'user_id': data['user_id'],
      'posted_ago': 'Just now',
      'created_at': DateTime.now().toIso8601String(),
    });

    return TripPost(
      id: id,
      userName: data['user_name'] ?? 'User',
      userInitials: _initials(data['user_name'] ?? 'U'),
      destination: data['destination'],
      startDate: data['start_date'] ?? 'TBD',
      endDate: data['end_date'] ?? 'TBD',
      groupSize: data['group_size'] ?? 4,
      currentMembers: 1,
      interests: List<String>.from(data['interests'] ?? []),
      description: data['description'] ?? '',
      postedAgo: 'Just now',
    );
  }

  // ─── Chat Messages ───

  static Future<List<ChatMessage>> getChatHistory(String tripId,
      {int limit = 200, String? currentUserId}) async {
    final db = await database;
    final results = await db.query(
      'chat_messages',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'timestamp ASC',
      limit: limit,
    );

    return results.map((row) {
      final senderId = row['sender_id'] as String? ?? '';
      return ChatMessage(
        id: row['id'] as String,
        senderId: senderId,
        senderName: row['sender_name'] as String? ?? 'Unknown',
        senderInitials: row['sender_initials'] as String? ?? '??',
        text: row['text'] as String? ?? '',
        messageType: ChatMessage.fromJson({'message_type': row['message_type']}).messageType,
        mediaPath: row['media_path'] as String?,
        mediaMimeType: row['media_mime_type'] as String?,
        fileName: row['file_name'] as String?,
        fileSize: row['file_size'] as int?,
        rating: (row['rating'] as num?)?.toDouble(),
        timestamp: DateTime.tryParse(row['timestamp'] as String? ?? '') ??
            DateTime.now(),
        isMe: currentUserId != null && senderId == currentUserId,
      );
    }).toList();
  }

  static Future<ChatMessage> saveMessage({
    required String tripId,
    required ChatMessage message,
  }) async {
    final db = await database;

    await db.insert(
      'chat_messages',
      {
        'id': message.id,
        'trip_id': tripId,
        'sender_id': message.senderId,
        'sender_name': message.senderName,
        'sender_initials': message.senderInitials,
        'text': message.text,
        'message_type': message.messageType.name,
        'media_path': message.mediaPath,
        'media_mime_type': message.mediaMimeType,
        'file_name': message.fileName,
        'file_size': message.fileSize,
        'rating': message.rating,
        'timestamp': message.timestamp.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return message;
  }

  // ─── Community Updates ───

  static Future<List<CommunityUpdate>> getCommunityUpdates(
      String placeId) async {
    final db = await database;
    final results = await db.query(
      'community_updates',
      where: 'place_id = ?',
      whereArgs: [placeId],
      orderBy: 'timestamp DESC',
    );

    return results.map((row) {
      return CommunityUpdate(
        id: row['id'] as String,
        placeId: row['place_id'] as String,
        userId: row['user_id'] as String? ?? '',
        userName: row['user_name'] as String? ?? '',
        userInitials: row['user_initials'] as String? ?? 'U',
        text: row['text'] as String? ?? '',
        timestamp:
            DateTime.tryParse(row['timestamp'] as String? ?? '') ??
                DateTime.now(),
        likes: row['likes'] as int? ?? 0,
        userLiked: (row['user_liked'] as int? ?? 0) == 1,
        images: _decodeList(row['images'] as String?),
        updateType: row['type'] as String? ?? 'tip',
      );
    }).toList();
  }

  static Future<CommunityUpdate> postCommunityUpdate({
    required String placeId,
    required String userId,
    required String userName,
    required String userInitials,
    required String text,
    required String updateType,
  }) async {
    final db = await database;
    final id = _uuid.v4();
    final now = DateTime.now();

    await db.insert('community_updates', {
      'id': id,
      'place_id': placeId,
      'user_id': userId,
      'user_name': userName,
      'user_initials': userInitials,
      'text': text,
      'type': updateType,
      'likes': 0,
      'user_liked': 0,
      'images': '[]',
      'timestamp': now.toIso8601String(),
    });

    return CommunityUpdate(
      id: id,
      placeId: placeId,
      userId: userId,
      userName: userName,
      userInitials: userInitials,
      text: text,
      timestamp: now,
      likes: 0,
      userLiked: false,
      images: [],
      updateType: updateType,
    );
  }

  static Future<bool> toggleLike(String placeId, String updateId) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE community_updates SET likes = likes + 1 WHERE id = ? AND place_id = ?',
      [updateId, placeId],
    );
    return true;
  }

  static Future<bool> deleteCommunityUpdate(
      String placeId, String updateId) async {
    final db = await database;
    final count = await db.delete(
      'community_updates',
      where: 'id = ? AND place_id = ?',
      whereArgs: [updateId, placeId],
    );
    return count > 0;
  }

  // ─── Dashboard / Favorites / Itineraries ───

  static Future<UserDashboard> getDashboard(String userId) async {
    final db = await database;

    // Get stats
    final statsRows = await db.query(
      'user_stats',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    final stats = statsRows.isNotEmpty
        ? statsRows.first
        : <String, dynamic>{};

    // Get favorites
    final favRows = await db.query(
      'favorites',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    final favIds = favRows.map((r) => r['place_id'] as String).toList();

    // Get saved itineraries count
    final itinRows = await db.query(
      'saved_itineraries',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    return UserDashboard(
      tripsCompleted: stats['trips_completed'] as int? ?? 0,
      placesVisited: stats['places_visited'] as int? ?? 0,
      reviewsContributed: stats['reviews_contributed'] as int? ?? 0,
      totalDaysTraveled: stats['total_days_traveled'] as int? ?? 0,
      citiesVisited: stats['cities_visited'] as int? ?? 0,
      totalBudgetSpent:
          (stats['total_budget_spent'] as num?)?.toDouble() ?? 0.0,
      favoritePlaceIds: favIds,
      savedItinerariesCount: itinRows.length,
    );
  }

  static Future<List<String>> getFavorites(String userId) async {
    final db = await database;
    final rows = await db.query(
      'favorites',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return rows.map((r) => r['place_id'] as String).toList();
  }

  static Future<bool> addFavorite(String userId, String placeId) async {
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
    return true;
  }

  static Future<bool> removeFavorite(String userId, String placeId) async {
    final db = await database;
    await db.delete(
      'favorites',
      where: 'place_id = ? AND user_id = ?',
      whereArgs: [placeId, userId],
    );
    return true;
  }

  static Future<SavedItinerary> saveItinerary({
    required String userId,
    required String destination,
    required int days,
    required double budget,
    required String summary,
    required Map<String, dynamic> itineraryJson,
    String status = 'planned',
  }) async {
    final db = await database;
    final id = _uuid.v4();
    final now = DateTime.now();

    await db.insert(
      'saved_itineraries',
      {
        'id': id,
        'user_id': userId,
        'destination': destination,
        'days': days,
        'budget': budget,
        'summary': summary,
        'itinerary_json': jsonEncode(itineraryJson),
        'status': status,
        'is_favorite': 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return SavedItinerary(
      id: id,
      userId: userId,
      destination: destination,
      days: days,
      budget: budget,
      summary: summary,
      itinerary: itineraryJson,
      status: status,
      isFavorite: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  static Future<List<SavedItinerary>> getSavedItineraries(
      String userId) async {
    final db = await database;
    final rows = await db.query(
      'saved_itineraries',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );

    return rows.map((row) {
      return SavedItinerary(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        destination: row['destination'] as String? ?? '',
        days: row['days'] as int? ?? 0,
        budget: (row['budget'] as num?)?.toDouble() ?? 0.0,
        summary: row['summary'] as String? ?? '',
        itinerary:
            jsonDecode(row['itinerary_json'] as String? ?? '{}'),
        status: row['status'] as String? ?? 'planned',
        isFavorite: (row['is_favorite'] as int? ?? 0) == 1,
        createdAt:
            DateTime.tryParse(row['created_at'] as String? ?? '') ??
                DateTime.now(),
        updatedAt:
            DateTime.tryParse(row['updated_at'] as String? ?? '') ??
                DateTime.now(),
      );
    }).toList();
  }

  static Future<bool> deleteItinerary(
      String itineraryId, String userId) async {
    final db = await database;
    final count = await db.delete(
      'saved_itineraries',
      where: 'id = ? AND user_id = ?',
      whereArgs: [itineraryId, userId],
    );
    return count > 0;
  }

  // ─── Notifications ───

  static Future<void> addNotification({
    required String userId,
    required String title,
    String? body,
    String type = 'info',
    String? relatedId,
  }) async {
    final db = await database;
    await db.insert('notifications', {
      'id': _uuid.v4(),
      'user_id': userId,
      'title': title,
      'body': body,
      'type': type,
      'related_id': relatedId,
      'is_read': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getNotifications(
      String userId) async {
    final db = await database;
    return await db.query(
      'notifications',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: 100,
    );
  }

  static Future<void> markNotificationRead(String notificationId) async {
    final db = await database;
    await db.update(
      'notifications',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [notificationId],
    );
  }

  static Future<void> markAllNotificationsRead(String userId) async {
    final db = await database;
    await db.update(
      'notifications',
      {'is_read': 1},
      where: 'user_id = ? AND is_read = 0',
      whereArgs: [userId],
    );
  }

  // ─── Expenses ───

  static Future<Map<String, dynamic>> addExpense({
    required String tripId,
    required String userId,
    required String userName,
    required String category,
    required String description,
    required double amount,
    String currency = 'USD',
    String? paidBy,
    String splitType = 'equal',
  }) async {
    final db = await database;
    final id = _uuid.v4();
    final now = DateTime.now();

    final data = {
      'id': id,
      'trip_id': tripId,
      'user_id': userId,
      'user_name': userName,
      'category': category,
      'description': description,
      'amount': amount,
      'currency': currency,
      'paid_by': paidBy ?? userName,
      'split_type': splitType,
      'created_at': now.toIso8601String(),
    };

    await db.insert('expenses', data);
    return data;
  }

  static Future<List<Map<String, dynamic>>> getExpenses(
      String tripId) async {
    final db = await database;
    return await db.query(
      'expenses',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'created_at DESC',
    );
  }

  static Future<bool> deleteExpense(String expenseId) async {
    final db = await database;
    final count = await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [expenseId],
    );
    return count > 0;
  }

  // ─── Emergency Contacts ───

  static Future<void> addEmergencyContact({
    required String userId,
    required String name,
    required String phone,
    String? relationship,
    bool isLocalService = false,
    String? destination,
  }) async {
    final db = await database;
    await db.insert('emergency_contacts', {
      'id': _uuid.v4(),
      'user_id': userId,
      'name': name,
      'phone': phone,
      'relationship': relationship,
      'is_local_service': isLocalService ? 1 : 0,
      'destination': destination,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getEmergencyContacts(
      String userId) async {
    final db = await database;
    return await db.query(
      'emergency_contacts',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'is_local_service DESC, name ASC',
    );
  }

  static Future<bool> deleteEmergencyContact(String contactId) async {
    final db = await database;
    final count = await db.delete(
      'emergency_contacts',
      where: 'id = ?',
      whereArgs: [contactId],
    );
    return count > 0;
  }

  // ─── Reset / Health ───

  static Future<void> resetState() async {
    final db = await database;
    await db.delete('chat_messages');
    await db.delete('community_updates');
    await db.delete('favorites');
    await db.delete('saved_itineraries');
    await db.delete('user_stats');
    await db.delete('expenses');
    await db.delete('notifications');
    await db.delete('emergency_contacts');
    // Reseed demo user
    await _seedDemoUser(db);
  }

  static Map<String, dynamic> healthCheck() {
    return {
      'status': 'ok',
      'service': 'WanderLand Local Backend',
      'version': '2.0',
      'type': 'embedded_dart_sqlite',
    };
  }

  // ─── Helpers ───

  static String _initials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.length >= 2
        ? name.substring(0, 2).toUpperCase()
        : name.toUpperCase();
  }

  static List<String> _decodeList(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      return List<String>.from(jsonDecode(jsonStr));
    } catch (_) {
      return [];
    }
  }
}
