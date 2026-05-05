import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripgenie/features/social/models/trip_model.dart';

class ChatRoomStateService {
  static const String _joinedRoomsKey = 'joined_chat_rooms';
  static const String _lastReadPrefix = 'chat_last_read_';

  static Future<Set<String>> _getJoinedRooms() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_joinedRoomsKey) ?? const <String>[]).toSet();
  }

  static Future<bool> isJoined(String roomId) async {
    return (await _getJoinedRooms()).contains(roomId);
  }

  static Future<void> joinRoom(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    final rooms = await _getJoinedRooms();
    rooms.add(roomId);
    await prefs.setStringList(_joinedRoomsKey, rooms.toList());
  }

  static Future<void> leaveRoom(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    final rooms = await _getJoinedRooms();
    rooms.remove(roomId);
    await prefs.setStringList(_joinedRoomsKey, rooms.toList());
  }

  static Future<void> markRead(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        _lastReadPrefix + roomId, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<DateTime?> getLastRead(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_lastReadPrefix + roomId);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  static Future<int> unreadCount(
      String roomId, List<ChatMessage> messages) async {
    final lastRead = await getLastRead(roomId);
    if (lastRead == null) {
      return messages.length;
    }

    return messages.where((m) => m.timestamp.isAfter(lastRead)).length;
  }
}
